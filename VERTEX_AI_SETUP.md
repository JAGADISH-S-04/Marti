# Firebase Vertex AI Setup Guide

## Current Status: ✅ APIS ENABLED

✅ **Vertex AI API** - Enabled successfully  
✅ **AI Platform API** - Enabled successfully  
✅ **Generative Language API** - Enabled successfully  

Your Firebase project **garti-sans** now has all required APIs enabled for Vertex AI.

## Next Steps

Your app should now successfully initialize Firebase Vertex AI. The initialization will:

1. First try **gemini-1.5-pro-002** (latest model)
2. Fall back to **gemini-1.5-flash** if needed
3. Provide detailed error messages if issues persist

## Required Setup Steps

### 1. Enable Vertex AI API in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: **garti-sans**
3. Navigate to **APIs & Services** > **Library**
4. Search for "Vertex AI API"
5. Click on "Vertex AI API" and click **ENABLE**

### 2. Enable Additional Required APIs

Also enable these APIs in the same way:
- **Vertex AI Gemini API**
- **Generative Language API** 
- **AI Platform API**

### 3. Set up Billing (Required for Vertex AI)

1. Go to **Billing** in Google Cloud Console
2. Ensure your project **garti-sans** has billing enabled
3. Vertex AI requires a billing account to function

### 4. Check Regional Availability

Vertex AI is available in specific regions. Recommended regions:
- **us-central1** (Iowa)
- **us-east4** (Northern Virginia)
- **europe-west4** (Netherlands)
- **asia-south2** (Delhi) — added based on your location

### 5. Verify Firebase Project Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **garti-sans**
3. Go to **Project Settings** > **General**
4. Ensure the project is properly linked to Google Cloud

### 6. Test the Setup

After enabling the APIs, restart your Flutter app. The enhanced initialization should now work with better error messages.

## Debugging Commands

Run these commands in your terminal to check the setup (PowerShell-friendly):

```powershell
# Check if you're authenticated with Google Cloud
gcloud auth list

# Set your project
gcloud config set project garti-sans

# Check enabled APIs (PowerShell uses Select-String instead of grep)
gcloud services list --enabled | Select-String "vertex|aiplatform|generative"

# Enable Vertex AI API (if not already enabled)
gcloud services enable aiplatform.googleapis.com
```

### Check Gemini model availability by region

Gemini models may be available only in certain regions. We try `us-central1`, `us-east4`, and `europe-west4` automatically. You can list available publisher models per region:

```powershell
# List publisher models (Vertex AI) in us-central1
gcloud ai publisher-models list --location=us-central1 | Select-String "gemini"

# Try another region
gcloud ai publisher-models list --location=us-east4 | Select-String "gemini"
gcloud ai publisher-models list --location=europe-west4 | Select-String "gemini"
gcloud ai publisher-models list --location=asia-south2 | Select-String "gemini"
```

If `gemini-1.5-pro-002` is not listed in your region, use stable aliases like `gemini-1.5-pro` or `gemini-1.5-pro-latest`. The app now tries stable aliases and falls back across regions automatically.

## Expected Console Output After Fix

When working correctly, you should see:
```
🔄 Initializing Firebase Vertex AI service...
🤖 Attempting to initialize with Gemini 1.5 Pro-002 (latest)...
✅ Firebase Vertex AI initialized successfully with gemini-1.5-pro-002
🤖 Vertex AI service initialized successfully
```

## If Issues Persist

1. Check the exact error message in the Flutter console
2. Verify your Google Cloud project has Vertex AI enabled
3. Ensure billing is set up
4. Try the fallback model (gemini-1.5-flash) first
5. Check regional availability for Vertex AI

## Fallback Strategy

If Vertex AI still doesn't work, the app will fall back to the regular Google Generative AI service, though with reduced functionality for workshop generation.