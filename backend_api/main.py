import cv2
import json
import os
import numpy as np
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List

app = FastAPI(title="Transignition Backend - Fisherface")

# Enable CORS for Flutter app or Web app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "model")
MODEL_PATH = os.path.join(MODEL_DIR, "fisherface_model.yml")
LABEL_MAP_PATH = os.path.join(MODEL_DIR, "label_map.json")
DATASET_DIR = os.path.join(MODEL_DIR, "dataset")

# Use Haar Cascade for Face Detection
cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
face_cascade = cv2.CascadeClassifier(cascade_path)

if face_cascade.empty():
    print(f"WARNING: Could not load face cascade from {cascade_path}. Trying fallback path...")
    # Common path in some linux distros
    face_cascade = cv2.CascadeClassifier("/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml")

img_size = (200, 200)

def load_label_map():
    if os.path.exists(LABEL_MAP_PATH):
        with open(LABEL_MAP_PATH, "r") as f:
            return json.load(f)
    return {}

def save_label_map(label_map):
    with open(LABEL_MAP_PATH, "w") as f:
        json.dump(label_map, f)

@app.get("/")
def root():
    return {"message": "Transignition Backend API Running"}

@app.get("/status")
def get_status():
    """
    Endpoint untuk mengecek apakah model dan label map sudah terdeteksi oleh API.
    """
    model_exists = os.path.exists(MODEL_PATH)
    label_map_exists = os.path.exists(LABEL_MAP_PATH)
    label_map = load_label_map() if label_map_exists else {}
    
    return {
        "model_found": model_exists,
        "model_path": MODEL_PATH,
        "label_map_found": label_map_exists,
        "label_map_path": LABEL_MAP_PATH,
        "registered_users_count": len(label_map),
        "registered_users": label_map
    }

@app.post("/recognize")
async def recognize_face(file: UploadFile = File(...)):
    """
    Endpoint untuk testing/prediksi wajah pengguna.
    Menggunakan model FisherFace yang sudah dilatih (fisherface_model.yml).
    """
    if not os.path.exists(MODEL_PATH):
        raise HTTPException(status_code=400, detail="Fisherface model not found. Please train first.")
    
    label_map = load_label_map()
    # Inisialisasi FisherFace Recognizer
    model = cv2.face.FisherFaceRecognizer_create()
    model.read(MODEL_PATH)
    
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image file")
    
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.3, 5)
    
    if len(faces) == 0:
        return {"status": "failed", "message": "No face detected"}
    
    results = []
    for (x, y, w, h) in faces:
        face = gray[y:y+h, x:x+w]
        face_resized = cv2.resize(face, img_size)
        
        # Prediksi wajah
        label, confidence = model.predict(face_resized)
        name = label_map.get(str(label), "Unknown")
        
        results.append({
            "name": name,
            "label": int(label),
            "confidence": float(confidence),
            "bbox": {"x": int(x), "y": int(y), "w": int(w), "h": int(h)}
        })
        
    return {"status": "success", "results": results}


@app.post("/register")
async def register_face(username: str = Form(...), files: List[UploadFile] = File(...)):
    """
    Endpoint untuk registrasi wajah (Daftar Pengguna Baru) atau Update Wajah.
    Catatan Teknis FisherFace:
    Algoritma Fisherface TIDAK mendukung method update() layaknya LBPH.
    Sehingga setiap penambahan user baru / update, model perlu di retrain dari seluruh dataset.
    Endpoint ini akan mendeteksi wajah di foto yang dikirim, menyimpannya di folder `dataset/<username>`,
    lalu membaca SELURUH dataset yang ada di foldet tersebut untuk di-train ulang menjadi `fisherface_model.yml` yang baru.
    """
    if not os.path.exists(MODEL_DIR):
        os.makedirs(MODEL_DIR)
        
    os.makedirs(DATASET_DIR, exist_ok=True)
    user_dir = os.path.join(DATASET_DIR, username)
    os.makedirs(user_dir, exist_ok=True)
    
    # Hitung gambar yang ada untuk penamaan agar tidak overwrite jika update
    existing_images = len(os.listdir(user_dir)) if os.path.exists(user_dir) else 0
    saved_images = 0
    
    for file in files:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            continue
            
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.3, 5)
        
        for (x, y, w, h) in faces:
            # Crop dan save face region
            face = gray[y:y+h, x:x+w]
            face_resized = cv2.resize(face, img_size)
            filename = os.path.join(user_dir, f"{existing_images + saved_images}.jpg")
            
            success = cv2.imwrite(filename, face_resized)
            if success:
                saved_images += 1
            else:
                print(f"CRITICAL: Failed to write image to {filename}. Check permissions.")
            
    if saved_images == 0:
        raise HTTPException(status_code=400, detail="No faces detected in the uploaded images")
        
    # Proses Retrain Fisherface dari Dataset lokal
    images = []
    labels = []
    label_map = {}
    current_label = 0
    
    for person_name in os.listdir(DATASET_DIR):
        person_path = os.path.join(DATASET_DIR, person_name)
        if not os.path.isdir(person_path):
            continue
            
        label_map[str(current_label)] = person_name
        
        # Load images for each person
        for img_name in os.listdir(person_path):
            img_path = os.path.join(person_path, img_name)
            img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
            if img is not None:
                img_resized = cv2.resize(img, img_size)
                images.append(img_resized)
                labels.append(current_label)
                
        current_label += 1
        
    # Fisherface butuh sedikitnya 2 class berbeda (2 orang berbeda) untuk membentuk model
    # Jika sistem baru dan hanya ada 1 orang di dataset, hindari crash algoritma Fisherface
    unique_labels = len(set(labels))
    if unique_labels < 2:
        return {
            "status": "partial_success", 
            "message": f"Wajah tersimpan! Namun model Fisherface butuh minimal 2 user terdaftar untuk bisa di-training. Saat ini baru ada {unique_labels} user."
        }
        
    images_np = np.array(images)
    labels_np = np.array(labels)
    
    # Train
    model = cv2.face.FisherFaceRecognizer_create()
    model.train(images_np, labels_np)
    
    # Save model and map
    model.save(MODEL_PATH)
    save_label_map(label_map)
    
    return {"status": "success", "message": f"Successfully registered {username}. Saved {saved_images} face data. Model retrained and updated."}
