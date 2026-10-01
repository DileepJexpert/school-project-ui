# School Project Configuration Summary

Saved configuration settings for local development and future Cloudflare production deployment.

---

## 1. Local Development Settings (Active Today)

### **A. Local Cloudflare Worker Backend (Primary)**
* **Command:**
  ```powershell
  cd C:\dileepkm\Learning\School-project\cloudflare\worker
  npx wrangler dev
  ```
* **Local API Base URL:** `http://localhost:8787/api`
* **Local Health Check:** `http://127.0.0.1:8787/health/live`
* **Local OpenAPI Docs:** `http://127.0.0.1:8787/docs`

### **B. Local FastAPI Backend (Alternative)**
* **Command:**
  ```powershell
  cd C:\dileepkm\Learning\School-project\backend
  .\.venv\Scripts\Activate.ps1
  python -m uvicorn app.main:app --reload --port 8000
  ```
* **Local API Base URL:** `http://localhost:8000/api`

### **C. Local Flutter Frontend**
* **Command (targeting Local Worker):**
  ```powershell
  cd C:\dileepkm\Learning\School-project
  flutter run -d chrome --release --dart-define=API_BASE_URL=http://localhost:8787/api
  ```

---

## 2. Seeded Local Credentials

* **School Code:** `risingstar`
* **School Name:** Rising Star Academy
* **City / Board:** Bengaluru / CBSE
* **Admin Email:** `admin@risingstar.edu`
* **Admin Password:** `Admin123!`
* **Role:** `SCHOOL_ADMIN`

---

## 3. Saved Cloudflare Staging & Production Settings

These settings are saved for when you are ready to deploy live to Cloudflare again:

* **Account ID:** `24e366c9448ef4c466bffe6f17efa51b`
* **Account Owner:** `todileepmaurya@gmail.com`
* **Target Website Domain:** `schools.katixo.com`
* **Target API Domain:** `schools-api.katixo.com`

### **Deployed Staging Resources:**
* **Staging D1 Database:** `school-staging-d1`
* **D1 Database ID:** `e27122b3-e2ba-474f-b7b3-dc7cddd39a89`
* **Staging Worker API URL:** `https://school-api-staging.todileepmaurya.workers.dev`
* **Staging Frontend Pages:** `https://school-staging.pages.dev`

### **Cloudflare API Token Permissions Required for Cutover:**
When ready to connect `schools.katixo.com`, the API token requires:
1. `Account` → `Workers Scripts` → `Edit`
2. `Account` → `D1` → `Edit`
3. `Account` → `Cloudflare Pages` → `Edit`
4. `Zone` → `DNS` → `Edit` *(Zone: `katixo.com`)*
5. `Zone` → `Workers Routes` → `Edit` *(Zone: `katixo.com`)*

---

## 4. D1 Database Schema State

* **Migration `0001_initial.sql`:** Base probe tables (`schema_versions`, `tenants`)
* **Migration `0002_school_schema.sql`:** Full 44 school application model tables
* **Status:** Verified 100% compatible locally and ready for live synchronization when needed.
