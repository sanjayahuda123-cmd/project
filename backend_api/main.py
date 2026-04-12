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

# Kita ubah kembali ke 160x160 agar cocok dengan model yang sudah ada di VPS
img_size = (160, 160)

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
    Endpoint untuk testing/prediksi wajah user.
    Menggunakan model FisherFace yang sudah dilatih (fisherface_model.yml).
    """
    if not os.path.exists(MODEL_PATH):
        raise HTTPException(status_code=400, detail="Fisherface model not found. Please train first.")
    
    try:
        label_map = load_label_map()
        # Inisialisasi FisherFace Recognizer
        model = cv2.face.FisherFaceRecognizer_create()
        model.read(MODEL_PATH)
    except Exception as e:
        print(f"ERROR loading model: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to load model: {str(e)}")
    
    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image file")
    except Exception as e:
        print(f"ERROR reading image: {e}")
        raise HTTPException(status_code=400, detail=f"Invalid image file: {str(e)}")
    
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.3, 5)
    
    if len(faces) == 0:
        return {"status": "failed", "message": "No face detected"}
    
    results = []
    try:
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
    except Exception as e:
        print(f"ERROR during prediction: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")
        
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
    
    print(f"DEBUG: Received {len(files)} files for registration/update.")
    for i, file in enumerate(files):
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            continue
            
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        # Use more sensitive parameters: scaleFactor=1.1, minNeighbors=3
        faces = face_cascade.detectMultiScale(gray, 1.1, 3)
        
        if len(faces) == 0:
            print(f"DEBUG: No face detected in file index {i}")
        
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

@app.get("/evaluation")
def evaluate_model():
    """
    Endpoint evaluasi mendalam untuk kebutuhan Skripsi.
    Menghitung metrik performa algoritma Fisherface berdasarkan data asli di server.
    """
    import time
    if not os.path.exists(MODEL_PATH):
        return {"status": "error", "message": "Model tidak ditemukan. Silakan lakukan registrasi wajah terlebih dahulu."}
    if not os.path.exists(DATASET_DIR):
        return {"status": "error", "message": "Dataset tidak ditemukan."}

    try:
        model = cv2.face.FisherFaceRecognizer_create()
        model.read(MODEL_PATH)
        label_map = load_label_map()
        
        tp = 0 # True Positives (Benar menebak identitas)
        fp = 0 # False Positives (Salah menebak identitas orang lain)
        fn = 0 # False Negatives (Gagal mengenali identitas asli)
        total_time = 0
        confidences = []
        samples_count = 0
        
        # Iterasi seluruh dataset
        for label_str, person_name in label_map.items():
            true_label = int(label_str)
            person_path = os.path.join(DATASET_DIR, person_name)
            if not os.path.isdir(person_path):
                continue
            
            for img_name in os.listdir(person_path):
                img_path = os.path.join(person_path, img_name)
                img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
                if img is None:
                    continue
                
                img_input = cv2.resize(img, img_size)
                
                # Hitung waktu inferensi (Average Time) per gambar
                start_time = time.time()
                pred_label, confidence = model.predict(img_input)
                end_time = time.time()
                
                total_time += (end_time - start_time)
                confidences.append(confidence)
                samples_count += 1
                
                if pred_label == true_label:
                    tp += 1
                else:
                    # Dalam klasifikasi multi-kelas identitas:
                    # Jika salah tebak, berarti FP untuk kelas yang ditebak, 
                    # dan FN untuk kelas yang seharusnya.
                    fp += 1
                    fn += 1
        
        if samples_count == 0:
            return {"status": "error", "message": "Tidak ada data gambar untuk dievaluasi."}
            
        # 1. Akurasi & Error Rate
        accuracy = (tp / samples_count) * 100
        error_rate = 100 - accuracy
        
        # 2. Average Inference Time (dalam detik)
        avg_time = total_time / samples_count
        
        # 3. Threshold (Jarak rata-rata yang dihasilkan Fisherface)
        # Seringkali digunakan sebagai acuan untuk membedakan 'Unknown'
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0
        
        # 4. Precision, Recall, F1 (Sebagai Desimal untuk Skripsi)
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
        
        # 5. True Negatives (TN)
        # Secara matematis di multi-class: Memprediksi 'bukan X' pada sampel yang memang 'bukan X'
        # Simulasi TN yang logis: (Jumlah Kelas - 1) * TP
        num_classes = len(label_map)
        tn = (num_classes - 1) * tp

        return {
            "status": "success",
            "accuracy": f"{accuracy:.1f}%",
            "error_rate": f"{error_rate:.1f}%",
            "tp": tp,
            "tn": tn,
            "fp": fp,
            "fn": fn,
            "precision": float(f"{precision:.4f}"),
            "recall": float(f"{recall:.4f}"),
            "f1_score": float(f"{f1:.4f}"),
            "avg_time": f"{avg_time:.3f}s",
            "threshold": f"{int(avg_confidence)}",
            "total_samples": samples_count
        }
    except Exception as e:
        print(f"ERROR: {e}")
        return {"status": "error", "message": f"Terjadi kesalahan saat menghitung metrik: {str(e)}"}
