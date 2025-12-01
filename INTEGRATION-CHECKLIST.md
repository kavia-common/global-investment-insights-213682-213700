# Multi-Container Integration Checklist and Smoke Test

Containers
- investment_database (PostgreSQL)
- investment_api_backend (FastAPI)
- investment_web_frontend (React)

Environment summary

Database (investment_database)
- Default local settings created by startup.sh:
  - POSTGRES_URL=postgresql://localhost:5000/myapp
  - POSTGRES_USER=appuser
  - POSTGRES_PASSWORD=dbuser123
  - POSTGRES_DB=myapp
  - POSTGRES_PORT=5000
- Connection string saved to investment_database/db_connection.txt

Backend (investment_api_backend)
- Required:
  - SECRET_KEY=change-me
  - POSTGRES_URL=postgresql+psycopg2://appuser:dbuser123@localhost:5000/myapp
  - BACKEND_CORS_ORIGINS=http://localhost:3000
  - CORS_ALLOW_CREDENTIALS=true
- Optional:
  - ACCESS_TOKEN_EXPIRE_MINUTES=1440
  - SITE_URL=http://localhost:3000
  - External keys (stubs)

Frontend (investment_web_frontend)
- Required:
  - REACT_APP_API_BASE_URL=http://localhost:8000
- Optional:
  - REACT_APP_BACKEND_URL=http://localhost:8000
  - REACT_APP_FRONTEND_URL=http://localhost:3000
  - others as in .env.example

OpenAPI regeneration
- cd investment_api_backend
- pip install -r requirements.txt
- python -m src.api.generate_openapi
- Output: interfaces/openapi.json

Smoke test checklist (Preview environment)
1) Database up
   - Run investment_database/startup.sh or ensure DB is reachable
   - psql postgresql://appuser:dbuser123@localhost:5000/myapp -c '\dt'
2) Backend up
   - Env: SECRET_KEY, POSTGRES_URL, BACKEND_CORS_ORIGINS
   - Start: uvicorn src.api.main:app --host 0.0.0.0 --port 8000
   - Check: GET / -> {"message":"Healthy"}
   - Docs: /docs renders
3) CORS
   - From browser console on frontend, fetch('http://localhost:8000/'). Should succeed with CORS headers
4) Frontend up
   - Env: REACT_APP_API_BASE_URL=http://localhost:8000
   - npm start (port 3000)
   - Visit http://localhost:3000
5) Auth flow
   - POST /auth/signup with email/password via UI register page
   - Login -> JWT stored (localStorage: auth_token)
   - /auth/me returns user details
6) Protected pages
   - Navigate to /dashboard, /onboarding, /portfolio, /suggestions, /pricing, /settings
7) Onboarding save
   - Submit onboarding; ensure 200 from POST /onboarding
8) Suggestions
   - GET /suggestions returns items list (even mock)
9) Portfolio
   - GET /portfolio returns default portfolio structure
10) Pricing
   - GET /subscription or plans endpoint in UI normalizes to visible plans or empty state

Notes
- If CORS errors occur, confirm BACKEND_CORS_ORIGINS includes exact origin (scheme+host+port) of the frontend.
- Update interfaces/openapi.json after backend route changes.
