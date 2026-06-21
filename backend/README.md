# NutriTrack AI Backend

## Kurulum

```powershell
cd backend
py -m venv .venv
.\.venv\Scripts\pip.exe install -r requirements.txt
Copy-Item .env.example .env
```

`.env` içindeki `GROQ_API_KEY` değerini https://console.groq.com/keys
adresinden aldığın anahtarla değiştir.

## Çalıştırma

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Kontrol:

```text
http://127.0.0.1:8000/health
http://127.0.0.1:8000/docs
```

Android emülatörü bilgisayardaki backend'e `http://10.0.2.2:8000`
adresiyle erişir. Gerçek telefonda bilgisayarın aynı Wi-Fi ağındaki IP adresini
kullan: örneğin `http://192.168.1.25:8000`.
