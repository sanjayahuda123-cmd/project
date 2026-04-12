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
        
        # Load images for each person (hanya gunakan 80% data awal untuk training produksi)
        all_imgs = [f for f in os.listdir(person_path) if f.endswith(('.jpg', '.png'))]
        all_imgs.sort() # URUTKAN agar pembagian 80/20 konsisten antara /register dan /evaluation
        
        train_count = int(0.8 * len(all_imgs))
        if train_count == 0 and len(all_imgs) > 0: 
            train_count = 1
            
        selected_imgs = all_imgs[:train_count] # 80% Awal untuk Training
        
        for img_name in selected_imgs:
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
    Endpoint evaluasi untuk Skripsi.
    Menggunakan model asli (produksi) untuk menguji 20% data yang TIDAK digunakan saat training.
    """
    import time
    if not os.path.exists(MODEL_PATH):
        return {"status": "error", "message": "Model produksi belum dibuat. Silakan registrasi data wajah terlebih dahulu."}
    if not os.path.exists(DATASET_DIR):
        return {"status": "error", "message": "Dataset tidak ditemukan."}

    try:
        # 1. Load Model Asli (Produksi)
        model = cv2.face.FisherFaceRecognizer_create()
        model.read(MODEL_PATH)
        label_map = load_label_map()
        
        test_data = [] # List of (image, true_label)
        total_training_samples = 0
        
        # 2. Ambil 20% data AKHIR dari setiap folder (Data yang tidak dipelajari model)
        for label_str, person_name in label_map.items():
            true_label = int(label_str)
            person_path = os.path.join(DATASET_DIR, person_name)
            if not os.path.isdir(person_path): continue
            
            images = [os.path.join(person_path, f) for f in os.listdir(person_path) if f.endswith(('.jpg', '.png'))]
            images.sort() # URUTKAN
            
            split_idx = int(0.8 * len(images))
            if split_idx == 0: split_idx = 1
            
            total_training_samples += split_idx
            test_paths = images[split_idx:] # Ambil 20% sisanya untuk Tes
            
            for p in test_paths:
                img = cv2.imread(p, cv2.IMREAD_GRAYSCALE)
                if img is not None:
                    test_data.append((cv2.resize(img, img_size), true_label))
        
        if not test_data:
            return {"status": "error", "message": "Data tidak cukup untuk pengujian 20% (Butuh minimal 2 gambar per orang)."}

        # 3. Pengujian menggunakan Model Produksi pada Data Tes
        tp = 0
        fp = 0
        fn = 0
        total_time = 0
        confidences = []
        y_true = []
        y_pred = []
        
        for img, true_label in test_data:
            start_time = time.perf_counter()
            pred_label, confidence = model.predict(img)
            end_time = time.perf_counter()
            
            total_time += (end_time - start_time)
            confidences.append(confidence)
            
            y_true.append(true_label)
            y_pred.append(pred_label)
            
            if pred_label == true_label:
                tp += 1
            else:
                fp += 1
                fn += 1
        
        samples_count = len(test_data)
        accuracy = (tp / samples_count) * 100
        error_rate = 100 - accuracy
        
        avg_time = total_time / samples_count
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0
        
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
        
        # TN Simulation
        num_classes = len(label_map)
        tn = (num_classes - 1) * tp

        return {
            "status": "success",
            "method": "Hold-out Testing (Last 20% unseen data)",
            "accuracy": f"{accuracy:.1f}%",
            "error_rate": f"{error_rate:.1f}%",
            "tp": tp,
            "tn": tn,
            "fp": fp,
            "fn": fn,
            "precision": float(f"{precision:.4f}"),
            "recall": float(f"{recall:.4f}"),
            "f1_score": float(f"{f1:.4f}"),
            "avg_time": f"{avg_time:.4f}s",
            "threshold": f"{int(avg_confidence)}",
            "total_samples_test": samples_count,
            "total_samples_train": total_training_samples,
            "y_true_names": [label_map.get(str(y), "Unknown") for y in y_true],
            "y_pred_names": [label_map.get(str(y), "Unknown") for y in y_pred]
        }
    except Exception as e:
        print(f"ERROR: {e}")
        return {"status": "error", "message": f"Gagal evaluasi 20%: {str(e)}"}

@app.get("/evaluation/plot")
def get_evaluation_plot():
    """
    Endpoint untuk menghasilkan grafik plot performa model lengkap (Bar Chart + Confusion Matrix).
    """
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import seaborn as sns
    import io
    import pandas as pd
    from sklearn.metrics import confusion_matrix
    from fastapi.responses import StreamingResponse

    # Ambil data evaluasi
    eval_data = evaluate_model()
    if eval_data.get("status") == "error":
        raise HTTPException(status_code=400, detail=eval_data.get("message"))

    y_true = eval_data['y_true_names']
    y_pred = eval_data['y_pred_names']
    labels = sorted(list(set(y_true)))

    # Buat Figure dengan 2 baris (Metrics & Confusion Matrix)
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 16))
    plt.subplots_adjust(hspace=0.4)

    # 1. Plot Metrics (Bar Chart)
    metrics = ['Accuracy', 'Precision', 'Recall', 'F1 Score']
    acc_val = float(eval_data['accuracy'].replace('%', '')) / 100
    values = [acc_val, eval_data['precision'], eval_data['recall'], eval_data['f1_score']]
    
    colors = ['#4CAF50', '#2196F3', '#FF9800', '#F44336']
    bars = ax1.bar(metrics, values, color=colors, width=0.5)
    ax1.set_title('Fisherface Performance Metrics', fontsize=16, fontweight='bold', pad=15)
    ax1.set_ylim(0, 1.1)
    ax1.set_ylabel('Score')
    ax1.grid(axis='y', linestyle='--', alpha=0.6)
    
    for bar in bars:
        yval = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2, yval + 0.01, f"{yval:.4f}", ha='center', va='bottom', fontweight='bold')

    # 2. Confusion Matrix (Heatmap)
    cm = confusion_matrix(y_true, y_pred, labels=labels)
    df_cm = pd.DataFrame(cm, index=labels, columns=labels)
    
    sns.heatmap(df_cm, annot=True, fmt='d', cmap='Blues', ax=ax2, cbar=False)
    ax2.set_title('Confusion Matrix', fontsize=16, fontweight='bold', pad=15)
    ax2.set_xlabel('Predicted Label', fontweight='bold')
    ax2.set_ylabel('True Label', fontweight='bold')
    
    # Putar label X agar tidak tumpang tindih
    plt.setp(ax2.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")

    # Simpan ke Buffer
    buf = io.BytesIO()
    plt.savefig(buf, format='png', bbox_inches='tight', dpi=150)
    plt.close()
    buf.seek(0)
    
    return StreamingResponse(buf, media_type="image/png", headers={"Content-Disposition": "attachment; filename=fisherface_evaluation_plot.png"})
