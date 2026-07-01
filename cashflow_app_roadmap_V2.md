# Cash Flow App — Complete Development Roadmap
### Built for a non-developer, using Codex CLI as your primary coding partner

---

> **Before you begin:** This app is genuinely ambitious for a first project. It touches iOS development, a backend server, a third-party financial API (Plaid), home screen widgets, and in-app subscriptions — each of which is a specialty in its own right. That's not a reason to stop — it's a reason to be patient with yourself. Budget **12–18 months** of part-time, consistent work. Codex will write the majority of your code, but you need enough understanding to direct it well, review what it produces, and debug problems. That knowledge takes time to build. Every phase below is designed with that in mind.
>
> **A cost-saving note:** the $99/year Apple Developer Program membership is **not required until Phase 5**. Phases 0–4 (Swift basics, data models, backend server, Plaid integration) all run fine on a free "Personal Team" account using the iOS Simulator. Hold off on paying for the Developer Program until you have a more substantial app to show for it — just see the bundle identifier note in Phase 0 so the eventual switch goes smoothly.

---

## Your AI Coding Partner: Codex CLI

Codex CLI is OpenAI's terminal-based coding agent. It's a lightweight tool that lives in your Mac's terminal, reads and edits files in your project, runs commands, and can plan and execute multi-step coding tasks. Think of it as a senior developer who never sleeps and never gets frustrated. You describe what you want in plain English, and it generates, edits, and runs the code. For someone with no development experience, this is transformative — but it works *much* better when you understand the concepts behind what it's building.

Because Codex runs in your terminal with full access to your project folder, it isn't just for writing Swift and JavaScript — it can also handle file organization tasks (renaming assets, sorting screenshots, tidying folders) just by asking it in plain English. You'll lean on that throughout the project, especially in Phases 7 and 9.

- **Install & quickstart guide:** https://developers.openai.com/codex/quickstart
- **CLI reference & features:** https://developers.openai.com/codex/cli
- **Open-source repo (for reference/troubleshooting):** https://github.com/openai/codex
- **How to use it well:** Be specific. Instead of "make the app work," say "create a SwiftUI view with a dark background that displays a large white number in the center." The more context you give, the better the output.

---

## Overview: The 9 Phases

| Phase | Focus | Estimated Duration |
|---|---|---|
| 0 | Setup & Orientation | 1–2 weeks |
| 1 | Swift & iOS Foundations | 6–10 weeks |
| 2 | App Architecture & Local Data | 4–6 weeks |
| 3 | Backend Server | 3–5 weeks |
| 4 | Plaid Integration | 3–5 weeks |
| 5 | WidgetKit | 4–6 weeks |
| 6 | Subscriptions (StoreKit / RevenueCat) | 2–3 weeks |
| 7 | Design, Polish & Onboarding | 4–6 weeks |
| 8 | Testing & Beta | 2–3 weeks |
| 9 | App Store Launch | 2–3 weeks |

**Total estimated time:** 31–49 weeks (roughly 8–12 months at consistent part-time pace)

---

## Phase 0 — Setup & Orientation
**Duration: 1–2 weeks**
**Goal: Get your entire environment ready so you can actually build things.**

This phase has no code. It's entirely about getting the right tools installed, the right accounts created, and a mental model of how everything fits together.

### Things to Set Up

**1. Apple Developer Account (can wait until Phase 5)**
You'll eventually need this — $99/year — for App Groups (Phase 5), extended testing on a real iPhone, and submitting to the App Store. It is **not required for Phases 0–4**, which run entirely on the iOS Simulator with a free "Personal Team" account.
- Cost: $99/year
- Sign up: https://developer.apple.com/programs/enroll/
- **When to actually do this:** about 1–2 weeks before you start Phase 5, since approval can take a day or two and you don't want it blocking that phase.
- **Do this now regardless:** when you create your Xcode project, give it a real reverse-domain bundle identifier (e.g., `com.yourname.cashflow`) instead of a placeholder — even on a free Personal Team. Changing it later installs a duplicate copy of the app on your simulator and can trigger confusing provisioning/signing errors.

**2. Xcode**
Apple's official development environment. All iOS apps are built here.
- Download: Free from the Mac App Store (search "Xcode")
- Requirements: A Mac computer running macOS 14 (Sonoma) or later
- ⚠️ Xcode is large (~15GB). Start this download before doing anything else.

**3. Codex CLI**
- Install guide: https://developers.openai.com/codex/quickstart
- Install via Homebrew (`brew install codex`) or npm (`npm i -g @openai/codex`)
- Requires Node.js if installing via npm — Homebrew is the simpler path on Mac
- Run `codex login` and sign in with your ChatGPT account (or an API key)

**4. Homebrew (Mac package manager)**
A tool that lets you install developer software easily from the terminal.
- Install: https://brew.sh (one-line command, paste it into Terminal)
- You'll use this to install backend tools and Codex CLI itself

**5. Git + GitHub Account**
Git is how developers save and track their work. GitHub is where it's stored online. Think of it like Google Drive, but for code — with the ability to rewind to any previous version.
- GitHub account: https://github.com (free)
- Install Git via Homebrew: `brew install git`

**6. Plaid Developer Account**
You'll need this for bank syncing. Start the account now — approval for production access takes time.
- Sign up: https://dashboard.plaid.com/signup
- You'll work in sandbox mode (fake bank data) for most of development.

**7. A Code Editor (VS Code)**
While Xcode handles iOS code, you'll write backend code in VS Code. Codex also has a VS Code extension if you want it integrated directly into your editor as well as the terminal.
- Download: https://code.visualstudio.com (free)

### Things to Learn This Phase

- What is a terminal / command line? (You'll use it a lot)
- What is Git and why does version control matter?
- Basic Mac Terminal navigation: `cd`, `ls`, `mkdir`, `pwd`

### Resources
- **Terminal basics for beginners:** https://www.youtube.com/watch?v=aKRYQsKR46I (freeCodeCamp, 1hr)
- **Git & GitHub crash course:** https://www.youtube.com/watch?v=RGOj5yH7evk (freeCodeCamp, 1hr)
- **What is Xcode? (overview):** https://www.youtube.com/watch?v=CwA1VWP0Ldw (Sean Allen, 15min)

### How Codex Helps Here
Once installed, open your project folder in terminal, run `codex`, and try asking it: "explain what each file in this folder does." Get comfortable talking to it in plain English before you write a single line of code.

### Milestone ✓
- Mac with Xcode installed and open
- GitHub account created, first empty repository made
- Codex CLI installed, logged in, and responding
- Plaid account created
- Cash Flow project created in Xcode with a proper bundle identifier (e.g., `com.yourname.cashflow`), running on a free Personal Team
- *(Apple Developer Program enrollment: deferred — revisit ~1–2 weeks before Phase 5)*

---

## Phase 1 — Swift & iOS Foundations
**Duration: 6–10 weeks**
**Goal: Learn enough Swift and SwiftUI to understand what Codex builds for you.**

This is the longest and most important phase. You don't need to become an expert programmer. You need to be fluent enough to read code, understand what it does, and give Codex intelligent instructions. Think of it like learning enough of a language to have a real conversation — you don't need to write poetry.

### What You Need to Learn

**Swift Basics**
Swift is the programming language all iOS apps are written in. Cover these fundamentals:
- Variables and constants (`var` vs `let`)
- Data types: String, Int, Double, Bool
- Arrays and dictionaries
- If/else logic and switch statements
- Functions and how to call them
- Loops (for, while)
- Optionals (`?` and `!`) — one of the trickiest concepts; spend real time here
- Classes vs Structs (very important for iOS)
- Closures (a function stored in a variable)

**SwiftUI Basics**
SwiftUI is the framework you use to build the visual parts of your app. It replaced the older UIKit approach and is much more beginner-friendly.
- Views: `Text`, `Image`, `Button`, `VStack`, `HStack`, `ZStack`
- State management: `@State`, `@Binding`, `@ObservableObject`
- Navigation: `NavigationStack`, `NavigationLink`
- List views
- Sheets and modal presentations
- Custom colors and fonts
- Dark mode support

**Xcode Fundamentals**
- How to create a new iOS project
- The canvas (SwiftUI preview)
- Running the simulator
- Understanding the project file structure
- The debug console
- Breakpoints (how to pause and inspect code while it runs)

### Resources

**Primary Course (do this first — it's free and excellent):**
- **100 Days of SwiftUI by Paul Hudson** — https://www.hackingwithswift.com/100/swiftui
  This is the best free structured iOS course available. Work through Days 1–40 to cover the fundamentals you need. Don't skip projects — they build muscle memory.

**YouTube Channels (use these for specific topics as they come up):**
- **Sean Allen** — https://www.youtube.com/@SeanAllen — Incredibly clear, practical iOS tutorials. Search his channel for any topic you're stuck on.
- **Stewart Lynch** — https://www.youtube.com/@StewartLynch — Excellent depth on SwiftUI and WidgetKit specifically. You'll return to him in Phase 5.
- **Kavsoft** — https://www.youtube.com/@Kavsoft — Great for UI animations and custom components.

**For Swift language specifically:**
- **Swift in 100 Seconds (Fireship):** https://www.youtube.com/watch?v=nAchMctX4YA — Quick 2min overview to start
- **Swift full course (Codecademy):** https://www.codecademy.com/learn/learn-swift — Good structured alternative

### How Codex Helps Here
As you learn each concept, practice by asking Codex to explain code it generates. Example: ask it to "explain this code to me line by line as if I'm a beginner." Use it as a tutor, not just a code generator.

### Project to Build in This Phase
Build a simple "Spending Log" app — a list where you can add entries with a name and dollar amount, delete them, and see a running total. It won't connect to anything real, but it exercises everything you've learned. Have Codex guide you through it, and try to understand every line.

### Milestone ✓
- Completed Days 1–40 of 100 Days of SwiftUI
- Can read a SwiftUI file and explain roughly what it does
- Built the practice Spending Log app
- Understand what `@State` and `@ObservableObject` mean

---

## Phase 2 — App Architecture & Local Data
**Duration: 4–6 weeks**
**Goal: Learn how to structure a real app and store data on the device.**

Before adding any real features, you need to understand how professional apps are organized. Without this, your codebase becomes a mess that Codex can't navigate effectively.

### What You Need to Learn

**MVVM Architecture**
MVVM (Model-View-ViewModel) is the standard pattern for iOS apps. It separates your data logic from your UI. This sounds abstract, but it's crucial:
- **Model:** Your data (a Transaction, a Widget, a User)
- **View:** The SwiftUI screen the user sees
- **ViewModel:** The logic that connects them

Every screen in Cash Flow will follow this pattern.

**SwiftData (Apple's modern local database)**
Cash Flow stores a lot of information locally on the user's device: widget configurations, transaction history, discretionary balance, income events. SwiftData is Apple's built-in tool for this.
- Defining data models with `@Model`
- Querying stored data with `@Query`
- Creating, updating, and deleting records
- Relationships between data models (e.g., a Widget has many Transactions)

**For Cash Flow specifically, you'll model:**
- `Widget` — name, type, budget, period, spending categories
- `Transaction` — amount, date, merchant, category, plaidID
- `IncomeEvent` — amount, date, depositedAt
- `UserSettings` — savings percentage, subscription status

**Async/Await (handling things that take time)**
Fetching bank data from Plaid takes time. You need to understand asynchronous programming — how to tell the app "go get this data, and when it arrives, update the screen."
- `async` functions
- `await` keyword
- `Task {}` blocks
- Error handling with `do/catch`

**App Groups (critical for widgets — hands-on setup deferred to Phase 5)**
Widgets run as a separate process from your main app. To share data between them — e.g., so the widget can show current spending — you use App Groups, a shared container both the app and widget can read from. **App Groups requires a paid Apple Developer Program membership**, so the actual Xcode configuration is deferred to Phase 5, right before you build the widget extension. For now, just understand the concept:
- What App Groups are and why widgets need them
- The general idea of writing to and reading from a shared UserDefaults container
- Understanding why this matters for WidgetKit (preview of Phase 5)

### Resources
- **MVVM explained simply:** https://www.youtube.com/watch?v=-Fm3tKuFtmQ (Sean Allen, 20min)
- **SwiftData full tutorial:** https://www.youtube.com/watch?v=vR71LNBSRGE (Sean Allen)
- **Async/Await in Swift:** https://www.youtube.com/watch?v=eSEFCGbMBEA (Sean Allen)
- **App Groups for WidgetKit:** https://www.youtube.com/watch?v=jFBFpFECPcY (Stewart Lynch)
- **Hacking with Swift — SwiftData:** https://www.hackingwithswift.com/swift/5.9/swiftdata

### How Codex Helps Here
Start your actual Cash Flow project in Xcode. Ask Codex to scaffold the data models: "create SwiftData models for a Cash Flow app with Widget, Transaction, IncomeEvent, and UserSettings models." Review every line it writes.

### Milestone ✓
- Understand MVVM and can explain it in plain English
- Cash Flow project created in Xcode with data models defined
- Data can be saved and retrieved locally on a simulator
- *(App Groups setup deferred to Phase 5 — requires paid Apple Developer Program membership)*

---

## Phase 3 — Backend Server
**Duration: 3–5 weeks**
**Goal: Build a small server that securely handles Plaid communication.**

This phase surprises most people. "Wait, I need a backend? It's just an iPhone app." Yes — and here's why.

**Why You MUST Have a Backend**
Plaid requires a private API key to function. If you put that key directly in your iOS app, anyone could extract it from the app file and use it to access your users' bank data. Plaid explicitly prohibits this. The solution: a small server that sits between your app and Plaid. Your app talks to your server, your server talks to Plaid with the secret key safely stored on the server side.

Your backend will handle:
1. Creating Plaid Link tokens (used to launch the bank connection UI)
2. Exchanging public tokens for access tokens (after a user connects their bank)
3. Fetching transactions on a schedule
4. Receiving and verifying Plaid webhooks (notifications when new transactions arrive)

### What You Need to Learn

**Node.js Basics**
Node.js lets you run JavaScript on a server. It's the most beginner-friendly backend option and has excellent Plaid SDK support.
- What is a server?
- Variables, functions, arrays, objects in JavaScript
- npm (Node Package Manager) — how to install libraries
- `require` / `import` syntax

**Express.js**
Express is a simple framework for building servers in Node.js. You'll use it to create API endpoints — URLs your iPhone app can call.
- Creating a basic server
- Defining routes (`GET /transactions`, `POST /create-link-token`)
- Handling JSON requests and responses
- Middleware

**Environment Variables**
How to store secret keys (like your Plaid API key) safely so they never end up in your code.
- `.env` files
- `dotenv` npm package
- Never committing secrets to GitHub (`.gitignore`)

**Hosting Your Server**
Your server needs to run somewhere on the internet so your app can reach it. Good options for beginners:
- **Railway** — https://railway.app (recommended: free tier, very easy to deploy)
- **Render** — https://render.com (also easy, has free tier)
- **Fly.io** — https://fly.io (more control, slightly more complex)

**Webhooks**
Plaid uses webhooks to notify your server of new transactions. A webhook is just Plaid making a POST request to a URL on your server.
- How to receive a webhook in Express
- Verifying webhook signatures (security)
- Triggering a widget refresh after new transactions arrive

### Resources
- **Node.js crash course:** https://www.youtube.com/watch?v=fBNz5xF-Kx4 (Traversy Media, 1.5hrs)
- **Express.js crash course:** https://www.youtube.com/watch?v=L72fhGm1tfE (Traversy Media, 1.5hrs)
- **Environment variables & dotenv:** https://www.youtube.com/watch?v=17UVejOw3zA (Traversy Media, short)
- **Deploy Node app to Railway:** https://www.youtube.com/watch?v=HCCkVz25UU4
- **REST APIs explained:** https://www.youtube.com/watch?v=-MTSQjw5DrM (Fireship, 6min)

### How Codex Helps Here
Codex is exceptional at building backends. Once you understand the concepts, let it write the server code: ask it to "create an Express.js server with endpoints for Plaid link token creation, public token exchange, and a webhook handler." You should be able to read and explain every route it creates.

### Milestone ✓
- Node.js and Express server running locally
- Three core Plaid endpoints created (link token, token exchange, webhook)
- Server deployed to Railway and accessible from the internet
- `.env` file used for secrets, secrets NOT in GitHub

---

## Phase 4 — Plaid Integration
**Duration: 3–5 weeks**
**Goal: Connect Cash Flow to real bank data.**

This is where the app starts to feel real. Plaid is a well-documented API with a good iOS SDK. The work here splits between your iOS app and your backend server.

### What You Need to Learn

**How Plaid Works (the full flow)**
1. Your app calls your server: "create a link token for this user"
2. Your server calls Plaid, gets a link token, sends it to your app
3. Your app opens Plaid Link (Plaid's built-in bank search UI) using that token
4. User searches for their bank, logs in, selects accounts
5. Plaid Link returns a `public_token` to your app
6. Your app sends that `public_token` to your server
7. Your server exchanges it for a permanent `access_token` and stores it
8. From now on, your server uses that `access_token` to fetch transactions

**Plaid Link iOS SDK**
- Adding PlaidLink to your Xcode project via Swift Package Manager
- Presenting the Plaid Link UI
- Handling the callback with the public token
- Error and exit handling

**Transaction Syncing**
- Using `/transactions/sync` endpoint (Plaid's recommended approach)
- Storing transactions in SwiftData
- De-duplicating transactions (so the same purchase doesn't appear twice)
- Handling transaction updates and removals

**Direct Deposit Detection**
For the Discretionary Number widget, Cash Flow needs to detect when a paycheck arrives. You'll look for:
- Transactions with category "Payroll" or "Direct Deposit"
- Or transactions from specific ACH transfer patterns
- When detected: calculate discretionary % and add to balance

**Category Mapping**
Plaid returns a category for each transaction (e.g., "Food and Drink > Restaurants"). You'll need to map these to Cash Flow's simpler categorization (Discretionary vs. not).

### Resources
- **Plaid official docs:** https://plaid.com/docs — The best resource. Bookmark it.
- **Plaid iOS Quickstart:** https://plaid.com/docs/quickstart/
- **Plaid Link iOS SDK:** https://plaid.com/docs/link/ios/
- **Plaid Transactions Sync:** https://plaid.com/docs/transactions/
- **Plaid webhook guide:** https://plaid.com/docs/transactions/webhooks/
- **Plaid YouTube channel:** https://www.youtube.com/@PlaidInc

### How Codex Helps Here
Plaid integration has a lot of moving parts. Ask Codex to handle specific pieces: "write a Swift function that calls my backend's /create-link-token endpoint and opens Plaid Link with the returned token." Keep each request focused and specific.

### Important: Sandbox Mode
During development, use Plaid's Sandbox environment. It has fake banks with fake credentials (`user_good` / `pass_good`). You never need to connect a real bank account until you're testing near launch.

### Milestone ✓
- Bank connection flow works end-to-end in Sandbox
- Transactions are fetched and stored in SwiftData
- Direct deposit events are detected and the discretionary balance updates
- Webhooks trigger a refresh in the app when new data arrives

---

## Phase 5 — WidgetKit
**Duration: 4–6 weeks**
**Goal: Build all three home screen widgets.**

> **Start here: enroll in the Apple Developer Program and set up App Groups.** This is the point where the free "Personal Team" account stops being enough — App Groups (which this entire phase depends on) requires a paid membership ($99/year, https://developer.apple.com/programs/enroll/). Enroll **1–2 weeks before** you plan to start this phase, since approval can take a day or two. Once approved:
> 1. In Xcode, go to your project's **Signing & Capabilities** tab and select your new paid team (not "Personal Team") in the Team dropdown.
> 2. Click **+ Capability**, add **App Groups**, then click the **+** under it to create a group identifier like `group.com.yourname.cashflow`.
> 3. Ask Codex: *"Create a small Swift helper class that reads and writes values to UserDefaults using my App Group container `group.com.yourname.cashflow`, with example functions for saving and reading a discretionaryBalance Double value. Add comments explaining why a normal UserDefaults wouldn't work here."*
> 4. Test the round-trip (save a value, read it back) before moving on — this is the foundation every widget in this phase reads from.

Widgets are the entire product. This phase is the most iOS-specific and requires the most patience. WidgetKit has a fundamentally different programming model from the rest of iOS.

### Understanding How WidgetKit Works (Read This Carefully)
Widgets are NOT live. They do not update continuously like an app screen. They are snapshots that iOS refreshes on a schedule (as often as every 15 minutes, but iOS controls the exact timing to preserve battery life). Here's the model:

1. Your widget extension provides a **Timeline** — a series of `TimelineEntry` objects, each representing what the widget should show at a specific time
2. iOS renders each entry at the appropriate time
3. Your widget code runs briefly, returns a timeline, then sleeps
4. When Plaid gets new data, your app writes to the shared App Groups container, then calls `WidgetCenter.shared.reloadAllTimelines()` to force a refresh

### What You Need to Learn

**WidgetKit Fundamentals**
- Widget Extension target (a separate mini-app inside your project)
- `TimelineProvider` protocol — `getSnapshot()` and `getTimeline()`
- `TimelineEntry` — your data at a point in time
- Widget views using SwiftUI
- `@main` entry point for widgets
- `Widget` and `WidgetConfiguration`
- `IntentConfiguration` vs `StaticConfiguration`
- App Groups for sharing data between app and widget

**All Three Sizes**
Each widget must look great at Small (2×2), Medium (2×4), and Large (4×4). Use `widgetFamily` environment variable to adapt the layout.

**Building Widget 1 — Bill Stack**
- Custom SwiftUI drawing of stacked bills
- Bills disappear as spending accumulates
- Denominations calculated from budget size
- Reset logic based on user-defined period

**Building Widget 2 — Progress Bar**
- Simple but requires careful color interpolation (green → yellow → red)
- Dollar amount display
- Label and period display
- The color shift needs to feel smooth, not abrupt

**Building Widget 3 — Discretionary Number**
- The simplest UI, the most complex logic
- Running balance calculation
- Large number display with custom typography
- Conditional secondary info at Large size

**Widget Configuration (Intent)**
Users can configure widgets from the home screen long-press menu. You'll use `AppIntentConfiguration` (the modern approach) to let users pick which widget to show in which slot.

### Resources
- **WidgetKit full series (Stewart Lynch):** https://www.youtube.com/@StewartLynch — Search "WidgetKit" — his series is the best available
- **WidgetKit intro (Apple WWDC):** https://developer.apple.com/videos/play/wwdc2020/10028/ (free, 30min)
- **App Groups + WidgetKit:** https://www.youtube.com/watch?v=jFBFpFECPcY (Stewart Lynch)
- **Interactive widgets & AppIntent:** https://developer.apple.com/videos/play/wwdc2023/10028/
- **Hacking with Swift — WidgetKit:** https://www.hackingwithswift.com/articles/224/tips-for-building-widgetkit-widgets
- **Creating custom shapes in SwiftUI (for Bill Stack):** https://www.youtube.com/watch?v=bU1Q-9KUQSI

### How Codex Helps Here
WidgetKit is where Codex shines. The structure is boilerplate-heavy and Codex knows it well. Start by asking it to "create a WidgetKit extension with a StaticConfiguration for a Progress Bar widget that reads from App Groups shared storage." Then iterate from there.

### Milestone ✓
- Apple Developer Program enrollment active, paid team selected in Signing & Capabilities
- App Group configured (e.g., `group.com.yourname.cashflow`) and shared storage helper tested
- Widget Extension added to Xcode project
- All three widgets appear on the home screen
- Widgets read from the shared App Groups container
- All three size variants work correctly
- Widgets refresh when the main app receives new Plaid data

---

## Phase 6 — Subscriptions (StoreKit / RevenueCat)
**Duration: 2–3 weeks**
**Goal: Implement the free tier and Cash Flow Pro subscription.**

### Free Tier vs. Pro Logic
- **Free:** One Discretionary Number widget, one spending goal
- **Pro:** Unlimited widgets of all types, full income split configuration

This requires "paywalling" features — checking whether the user has an active subscription before allowing certain actions.

### What You Need to Learn

**RevenueCat (Strongly Recommended Over Raw StoreKit)**
RevenueCat is a third-party service that wraps Apple's StoreKit in a much simpler API. It handles edge cases (subscription renewals, downgrades, restore purchases, family sharing) that would take weeks to implement manually. It has a free tier for indie developers.
- Sign up: https://www.revenuecat.com
- iOS SDK: https://www.revenuecat.com/docs/getting-started/installation/ios

**App Store Connect Setup**
Before any of this works, you configure your subscription products in App Store Connect:
- Create your app record in App Store Connect
- Set up a subscription group
- Define the "Cash Flow Pro" auto-renewable subscription with pricing
- Set up Sandbox test accounts for testing purchases

**Implementation**
- Initialize RevenueCat SDK at app launch
- Fetch available offerings (your subscription products)
- Present a paywall UI when a user tries a Pro feature
- Check `CustomerInfo` to know if a user is subscribed
- Restore purchases button (required by Apple)

### Resources
- **RevenueCat Getting Started:** https://www.revenuecat.com/docs/getting-started
- **RevenueCat iOS tutorial (RevenueCat YouTube):** https://www.youtube.com/@RevenueCat
- **In-App Purchases with RevenueCat (Sean Allen):** https://www.youtube.com/watch?v=CRFJGJfb7R4
- **App Store Connect subscriptions setup:** https://developer.apple.com/in-app-purchase/

### How Codex Helps Here
Ask Codex to "add RevenueCat to my SwiftUI app and create a paywall view that shows when a free user tries to add a second widget" — this is a well-defined task Codex handles very well.

### Milestone ✓
- RevenueCat integrated and initialized
- Subscription product configured in App Store Connect (Sandbox)
- Free tier limitations enforced in the UI
- Subscription purchase and restore work in Sandbox
- Paywall appears at the right moments

---

## Phase 7 — Design, Polish & Onboarding
**Duration: 4–6 weeks**
**Goal: Make Cash Flow look and feel like a premium indie app.**

### The Design Language
Cash Flow's aesthetic is defined in the spec: dark mode, techy, deep backgrounds, sharp typography, high-contrast data elements. No illustrations. No playful iconography. Clean and precise.

**Color Palette**
Define a consistent set of colors in your Xcode project as a Color Set:
- Background: near-black (not pure black — try `#0A0A0F` or `#111118`)
- Surface: slightly lighter dark (`#1A1A24`)
- Accent: a single sharp color for progress indicators and highlights (electric blue `#4A9EFF` or cool teal `#00D4B8`)
- Text primary: white
- Text secondary: mid-gray

**Typography**
iOS has excellent system fonts. Use SF Pro (the system default) — it's what Apple uses. For the large number in the Discretionary widget, use a heavier weight: `.fontWeight(.bold)` or `.fontWeight(.black)`.

### What to Build in This Phase

**Onboarding Flow (3–4 screens)**
1. Welcome + savings percentage input
2. Widget selection and customization
3. Budget setup (for Bill Stack / Progress Bar)
4. Bank connection (launches Plaid Link)

The onboarding should only show once, on first launch. Store a flag in SwiftData.

**Main Settings Hub**
The spec describes the main screen as a "Settings & Bank Connection hub." Build:
- Connected accounts section (sync status, reconnect button)
- Active widgets list with edit/delete
- Subscription status card with upgrade CTA
- Live widget preview panel (show a miniature version of each widget)

**Micro-interactions & Animation**
Small details make the app feel premium:
- Smooth color transitions in the Progress Bar
- Bills "burning" or fading when spending accumulates in Bill Stack
- Number counter animation on the Discretionary widget when balance updates
- Haptic feedback when widget resets

### Resources
- **SwiftUI animations crash course:** https://www.youtube.com/watch?v=zBSEsXlXbP4 (Kavsoft)
- **Custom dark mode design in SwiftUI:** https://www.youtube.com/watch?v=Hkv9jRnZQkI
- **SF Symbols (Apple's icon library):** https://developer.apple.com/sf-symbols/ — Free, 6000+ icons, use throughout
- **Haptic feedback in SwiftUI:** https://www.hackingwithswift.com/books/ios-swiftui/making-vibrations-with-uinotificationfeedbackgenerator-and-core-haptics
- **iOS Design Guidelines (Apple HIG):** https://developer.apple.com/design/human-interface-guidelines

### How Codex Helps Here
Beyond writing the SwiftUI code for these screens, Codex's terminal access makes it useful for organizing your asset folders too — rename icon files systematically, sort widget preview screenshots, organize App Store screenshot batches by size. Give it instructions in plain English, e.g.: "rename all files in this folder to follow the naming pattern widget_[type]_[size]_[number]."

### Milestone ✓
- Consistent color palette applied across entire app
- Onboarding flow complete and only appears on first launch
- Main settings hub functional
- At least one micro-interaction / animation per widget type
- App feels cohesive — not like individual pieces

---

## Phase 8 — Testing & Beta
**Duration: 2–3 weeks**
**Goal: Find and fix problems before real users do.**

### Types of Testing

**Personal Device Testing**
Connect your iPhone to your Mac with a cable (or wirelessly once set up). Run the app directly on your device. This is how you catch issues the simulator misses — real performance, real widget rendering, real Plaid behavior.

**TestFlight Beta**
TestFlight is Apple's official beta testing platform. You upload a build to App Store Connect, and invite testers via email. They install it like a normal app.
- Invite 10–20 people who represent your target users
- Specifically test: bank connection, widget accuracy, subscription flow, edge cases (zero balance, very large balance, no transactions)

**Things to Test Specifically for Cash Flow**
- What happens if Plaid sync fails mid-session?
- What if a user has 0 transactions?
- What if the discretionary balance goes negative?
- Do widgets update correctly after a new deposit?
- Do widgets show a sensible placeholder state before bank is connected?
- Does the app work on older iPhones (iPhone 12, 13)?
- Does everything look correct on small screens (iPhone SE)?

**Crashlytics**
Add Firebase Crashlytics (free) to capture crash reports from beta testers automatically.
- Add to project: https://firebase.google.com/docs/crashlytics/get-started?platform=ios

### Resources
- **TestFlight guide:** https://developer.apple.com/testflight/
- **Firebase Crashlytics setup:** https://firebase.google.com/docs/crashlytics/get-started?platform=ios
- **Testing in SwiftUI (Sean Allen):** https://www.youtube.com/watch?v=A_btT8ZKM7o

### How Codex Helps Here
Ask Codex to "find any potential edge cases or bugs in this SwiftData query for fetching transactions" — Codex is useful for code review even if it didn't write the code originally.

### Milestone ✓
- App tested on at least 2 physical iPhones
- TestFlight build live with at least 5 beta testers
- All critical flows tested: bank connection, widget display, subscription purchase
- Crashlytics added and reporting

---

## Phase 9 — App Store Launch
**Duration: 2–3 weeks**
**Goal: Ship it.**

### What App Store Submission Requires

**App Store Connect Setup**
- App name, subtitle, description (up to 4000 characters)
- Keywords (100 character limit — choose carefully for discoverability)
- Support URL (you'll need a simple website or landing page)
- Privacy Policy URL (required — especially with Plaid/financial data)

**Screenshots**
Apple requires screenshots at specific sizes. You need:
- iPhone 6.9" (iPhone 16 Pro Max) — required
- iPhone 6.5" (iPhone 11 Pro Max / 12 Pro Max) — required
- These can be created in the Xcode simulator + screenshot tool, or with a tool like Previewed (https://previewed.app)
Create 3–5 screenshots per size showing your best features. For Cash Flow: show the widget on a home screen, the bank connection screen, and the discretionary widget.

**Privacy Policy**
With Plaid integration, you are handling financial data. A privacy policy is not optional — legally or for App Review. Use a generator like https://www.privacypolicies.com (free tier works for indie apps) and make sure it accurately describes what data you collect and how it's used.

**App Tracking Transparency**
If you're not tracking users across apps (and Cash Flow shouldn't be), you can mark this correctly in App Store Connect and skip the ATT prompt. Make sure your Plaid and RevenueCat integrations are configured for no cross-app tracking.

**App Review Guidelines**
Apple's review team will check your app against their guidelines. Key things for Cash Flow:
- Financial apps face extra scrutiny — be thorough in your metadata
- You must explain the use of Plaid in your review notes
- Subscription apps must clearly disclose pricing and terms
- The restore purchases button must work
- Guidelines: https://developer.apple.com/app-store/review/guidelines/

**App Review Notes**
When submitting, you can include notes for the reviewer. Explain: "This app uses Plaid to sync bank transactions for display on home screen widgets. No financial transactions are initiated. Plaid credentials are stored server-side."

**App Preview Video (Optional but Powerful)**
A 15–30 second screen recording showing the app in use. This dramatically increases conversion on your App Store page. Record on a real device, show the widgets appearing on the home screen.

### Resources
- **App Store Connect guide:** https://developer.apple.com/app-store-connect/
- **App Store screenshots guide:** https://developer.apple.com/design/human-interface-guidelines/app-store-connect
- **App Store Review Guidelines:** https://developer.apple.com/app-store/review/guidelines/
- **ASO (App Store Optimization) for indie devs:** https://www.youtube.com/watch?v=zCHIBxMVUso
- **Privacy policy generator:** https://www.privacypolicies.com

### How Codex Helps Here
Use Codex's terminal access to batch-resize and organize your App Store screenshots, rename them to Apple's naming conventions, and keep your launch assets folder tidy — just describe what you want sorted and how.

### Milestone ✓
- App submitted to App Store review
- Privacy policy live at a URL
- All screenshot sizes uploaded
- Subscription pricing visible on App Store page
- **App APPROVED and live** 🎉

---

## Summary: Tools You Will Use

| Tool | Purpose | Cost |
|---|---|---|
| Xcode | Build and run the iOS app | Free |
| Codex CLI | Write, debug, and organize code/files | ChatGPT Plus/Pro subscription or API usage |
| GitHub | Version control / code backup | Free |
| VS Code | Write backend code | Free |
| Railway | Host your backend server | Free tier available |
| Plaid | Bank sync API | Free sandbox; production costs scale with users |
| RevenueCat | Subscription management | Free up to $2,500/mo revenue |
| Firebase Crashlytics | Crash reporting | Free |
| TestFlight | Beta testing | Free (requires Apple Developer account) |
| App Store Connect | App submission and management | Free (included in $99 Developer account) |
| Apple Developer Program | Required for App Groups (Phase 5 onward) and to ship | $99/year — enroll ~1–2 weeks before Phase 5, not in Phase 0 |

---

## Summary: Things You Will Learn

1. Mac Terminal / command line basics
2. Git version control
3. Swift programming language
4. SwiftUI framework
5. Xcode IDE
6. MVVM app architecture
7. SwiftData (local database)
8. Async/await programming
9. App Groups (data sharing)
10. Node.js and Express (backend server)
11. REST APIs
12. Environment variables and security
13. Plaid API and iOS SDK
14. Webhook handling
15. WidgetKit and Timeline providers
16. StoreKit / RevenueCat (subscriptions)
17. App Store Connect and App Review process
18. TestFlight beta distribution
19. Crash reporting

---

## A Note on Using Codex Effectively

Codex will be your most important tool. Here's how to get the most from it throughout this entire project:

**Be specific.** "Make the widget work" gives it nothing. "In my `DiscretionaryWidget.swift`, add a `.medium` size case to the switch statement that shows the balance number at 48pt and a secondary label 'Discretionary' at 12pt below it" — that's a buildable instruction.

**Review everything it writes.** Don't just paste code in and move on. Ask it to explain what each section does. This is how you learn.

**Use it for debugging.** When you get an error, paste the full error message and relevant code, and ask: "I'm getting this error: [paste error]. Here's the code: [paste code]. What's wrong and how do I fix it?"

**Use it for code review.** After you've built something, ask: "review this code for potential bugs, edge cases, or ways to improve it."

**Work inside Git.** Codex can modify your codebase directly, so commit your work before and after each task — that way you can always roll back if something goes wrong.

**Build your own vocabulary.** The better you understand the concepts from Phases 1–2, the better your instructions become — and the better the output Codex produces.

---

*Roadmap version 2.1 — Cash Flow iOS App (Codex CLI edition)*
*Estimated total project duration: 12–18 months (part-time)*
*v2.1 change: Apple Developer Program enrollment ($99/year) and App Groups setup moved from Phase 0/Phase 2 to the start of Phase 5 — not needed until widgets require shared storage.*
