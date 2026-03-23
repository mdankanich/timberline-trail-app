# Facebook Login Setup (Firebase + iOS)

Use this guide to enable Facebook authentication for Timberline Trail App.

## 1. Create Facebook app
1. Go to `https://developers.facebook.com`.
2. Open **My Apps** -> **Create App**.
3. Select the use case for **user authentication / Facebook Login** (often shown as "Authenticate and request data from users with Facebook Login").
4. Complete app creation.

## 2. Add Facebook Login product
1. In the Meta app dashboard, add the **Facebook Login** product.
2. Open **Facebook Login -> Settings**.
3. In **Valid OAuth Redirect URIs**, add:

`https://timberline-trail-app.firebaseapp.com/__/auth/handler`

## 3. Get credentials
1. In **App Settings -> Basic**, copy:
- **App ID**
- **App Secret**

## 4. Configure Firebase provider
1. Open Firebase Console -> **Authentication** -> **Sign-in method** -> **Facebook**.
2. Turn **Enable** on.
3. Paste **App ID** and **App Secret**.
4. Save.

## 5. Check authorized domains
1. In Firebase -> **Authentication** -> **Settings** -> **Authorized domains**.
2. Confirm your Firebase auth domain is present (for this project, it includes `timberline-trail-app.firebaseapp.com`).

## 6. Testing notes
- If your Meta app is in **Development mode**, only developers/testers added in Meta can sign in.
- For broad public use, complete Meta app review and switch app status appropriately.

## 7. Security notes
- Never commit App Secret to git.
- If a secret is accidentally exposed, rotate it immediately in Meta and update Firebase.

## 8. App-side integration reminder
This setup only enables provider configuration. The iOS app still needs code to exchange Facebook OAuth credentials with Firebase Auth.

Current app status: social Google/Facebook buttons are UI placeholders unless wired to provider SDK flow.
