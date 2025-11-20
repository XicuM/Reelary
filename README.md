# Insta2Cook 🍳

A beautiful Flutter app to extract recipes from Instagram Reels using Gemini API, with Material Design 3 UI and folder-based organization.

## ✨ Features

- 📱 **Extract Recipes**: Convert Instagram Reels into structured recipes automatically
- 📁 **Folder Organization**: Organize recipes with customizable emoji folders
- 🎨 **Material Design 3**: Modern, beautiful UI with dark mode support
- ✅ **Interactive Cooking**: Check off steps as you cook
- 💾 **Local Storage**: All recipes stored locally with SQLite
- 🌙 **Dark Mode**: Automatic theme switching based on system preferences

## Setup Instructions

### Prerequisites

**Required:** RapidAPI Instagram Downloader API - For downloading Instagram videos cross-platform

**Why use an API?** Instagram blocks direct video scraping. Using a third-party API service ensures the app works on all platforms (Android, iOS, Windows, macOS, etc.).

### App Setup

1.  **Initialize Flutter Project**
    Since this is a new project, you need to generate the platform-specific files (Android/iOS). Run the following command in your terminal:
    ```bash
    flutter create .
    ```

2.  **Configure Android Manifest**
    The app uses the `receive_sharing_intent` package to handle shared URLs from Instagram.
    After running `flutter create .`, check `android/app/src/main/AndroidManifest.xml`.
    Ensure the following `<intent-filter>` is present inside the `<activity>` tag:

    ```xml
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="text/plain" />
    </intent-filter>
    ```
    
    *Note: I have already created this file for you, but `flutter create` might overwrite it or require you to merge changes.*

3.  **API Keys Configuration**
    
    **a) Gemini API Key**
    Get your Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey).
    
    **b) RapidAPI Key**
    1. Sign up at [RapidAPI](https://rapidapi.com/)
    2. Subscribe to [Instagram Premium API 2023](https://rapidapi.com/sainikhilmaremanda-jgDbPvTvR/api/instagram-premium-api-2023) (has free tier)
    3. Copy your API key from the dashboard
    
    **c) Update .env file**
    Open the `.env` file in the root directory and add your keys:
    ```
    GEMINI_API_KEY=your_gemini_key_here
    RAPIDAPI_KEY=your_rapidapi_key_here
    RAPIDAPI_HOST=instagram-premium-api-2023.p.rapidapi.com
    INSTAGRAM_POST_INFO_ENDPOINT=/v1/post_info
    ```

4.  **Run the App**
    ```bash
    flutter run
    ```

## Features
-   **Share to App**: Share an Instagram Reel directly to Insta2Cook.
-   **Paste URL**: Manually paste a Reel URL.
-   **Gemini Extraction**: Uses Gemini 1.5 Flash to analyze the video and author's comment to extract ingredients and steps.
-   **Recipe Storage**: Saves recipes locally using SQLite.
