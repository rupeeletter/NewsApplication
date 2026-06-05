# Login UI Update Instructions

## ✅ Changes Made to Code

### 1. **sign_in_screen.dart** - Updated
- ✅ Removed "Forgot Password?" link
- ✅ Added "Login" title at the top in red color
- ✅ Changed logo reference to `assets/new_logo.png`
- ✅ Made Terms & Privacy Policy clickable (blue underlined links)
- ✅ Replaced "G" text with Google logo image (`assets/google_logo.png`)

### 2. **pubspec.yaml** - Updated
- ✅ Added `assets/new_logo.png` to assets
- ✅ Added `assets/google_logo.png` to assets

## 📋 Manual Steps Required

### Step 1: Add the New Logo
1. Save the new logo image (red and black "RL" logo) you provided as:
   - File name: `new_logo.png`
   - Location: `NewsApplication/assets/new_logo.png`
   - Size: Keep it around 200x200 pixels (transparent background)

### Step 2: Add Google Logo
1. Download the official Google "G" logo from: https://developers.google.com/identity/branding-guidelines
2. OR use this colored Google "G" logo
3. Save it as:
   - File name: `google_logo.png`
   - Location: `NewsApplication/assets/google_logo.png`
   - Size: 20x20 pixels (it will be displayed at this size)

### Step 3: Run Flutter Commands
```bash
cd NewsApplication
flutter pub get
flutter run
```

## 🎨 UI Features Implemented

### ✅ Top Section
- "Login" title in red/pink color
- New RL logo (100x100 size, no background)
- Clickable "Terms of Services" and "Privacy Policy" links in blue

### ✅ Main Card
- "Welcome back" heading
- Email field with icon
- Password field with icon and visibility toggle
- **Forgot Password REMOVED**
- Red/Pink "Login" button
- "OR" divider
- "Continue with Google" button with official Google logo

### ✅ Bottom Section
- "Don't have an account? Sign Up" text

## 📸 UI Matches Design
The UI now matches your provided design image with:
- Clean white card on grey background
- Proper spacing and rounded corners
- Google logo instead of just "G" text
- Clickable terms and privacy links
- No "Forgot Password" link

## 🔧 If Images Don't Show
If the images don't appear after adding them:
1. Stop the app
2. Run: `flutter clean`
3. Run: `flutter pub get`
4. Run: `flutter run`

## 📝 Notes
- The new logo should have a transparent background (no white box)
- The Google logo should be the official colored "G" from Google's branding guidelines
- Both images are placed in the `assets/` folder alongside other assets
