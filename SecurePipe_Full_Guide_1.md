# SecurePipe — Full Build Guide
**DevSecOps Portfolio Project · No Docker Required · Your Own Server**

---

## Before You Start — Understanding the Full Picture

Here is what you are building and why every piece matters:

You are writing a small Laravel API that has **real, working security vulnerabilities** baked into it on purpose. You host it on your own server so it is publicly accessible. You push the code to GitHub. GitHub Actions automatically runs four different security tools against your code and your live server every time you push. The tools catch the vulnerabilities, the pipeline fails, you fix the code, push again, and the pipeline goes green. You screenshot everything and write it up as a proper security report.

That complete loop — build, detect, exploit manually, fix, verify automatically — is DevSecOps. That is what you are demonstrating.

**What you need:**
- A server you control (you already have this)
- A domain or subdomain pointing to it (e.g. `vulnapi.yourdomain.com`)
- PHP 8.2+ and MySQL on the server
- Composer installed on the server
- A free GitHub account
- Burp Suite Community Edition on your local machine (free from portswigger.net)
- Semgrep CLI on your local machine (for testing locally before pushing)

**Cost: Zero naira.**

---

## Part 1 — Planning the Application

### What VulnAPI Is

VulnAPI is a simple **Notes API** — a backend for a note-taking application. Users can register, log in, create notes, read their notes, update them, and delete them. There is also an admin endpoint that lists all registered users.

The app itself is deliberately simple. The point is not the functionality. The point is:
1. It is realistic enough that the vulnerabilities make sense
2. It is simple enough that you can build it in a day
3. It has enough endpoints that the security tools have something to work with

### The Endpoints You Will Build

| Method | URL | What It Does | Who Can Use It |
|--------|-----|-------------|----------------|
| POST | `/vulnapi/register` | Create a new account | Anyone |
| POST | `/vulnapi/login` | Get a JWT token | Anyone |
| GET | `/vulnapi/notes` | List your own notes | Logged-in users |
| POST | `/vulnapi/notes` | Create a note | Logged-in users |
| GET | `/vulnapi/notes/{id}` | View a specific note | Logged-in users |
| PUT | `/vulnapi/notes/{id}` | Edit a note | Logged-in users |
| DELETE | `/vulnapi/notes/{id}` | Delete a note | Logged-in users |
| GET | `/vulnapi/search?keyword=` | Search notes by keyword | Logged-in users |
| GET | `/vulnapi/admin/users` | List all users | Should be admin only |

### The Six Vulnerabilities You Will Introduce

You are not randomly breaking things. Each vulnerability is a deliberate copy of how real developers make real mistakes. Here they are upfront so you understand the full picture before you write a single line:

| # | Vulnerability | OWASP Top 10 Category | Where It Lives |
|---|--------------|----------------------|---------------|
| V1 | SQL Injection | A03 — Injection | `/vulnapi/search` endpoint |
| V2 | Insecure Direct Object Reference (IDOR) | A01 — Broken Access Control | `/vulnapi/notes/{id}` |
| V3 | Missing Role Check on Admin Route | A01 — Broken Access Control | `/vulnapi/admin/users` |
| V4 | Mass Assignment | A08 — Software & Data Integrity | `/vulnapi/register` |
| V5 | No Rate Limiting on Login | A04 — Insecure Design | `/vulnapi/login` |
| V6 | Hardcoded Secrets Committed to Git | A02 — Cryptographic Failures | `.env` file |

---

## Part 2 — Setting Up GitHub (Do This First)

GitHub is not optional. It is where your pipeline lives.

### Step 1 — Create the Repository

1. Go to github.com and create a free account if you do not have one
2. Click **New Repository**
3. Name it `vulnapi`
4. Set it to **Public** (required — GitHub Actions is free for public repos)
5. Check **Add a README**
6. Click **Create Repository**

### Step 2 — Set Up GitHub Actions Secrets

Your pipeline needs to know certain things without them being visible in your code. GitHub Secrets handle this.

Go to your repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

| Secret Name | Value | Why |
|------------|-------|-----|
| `SEMGREP_APP_TOKEN` | Get from semgrep.dev after creating free account | Semgrep needs this to run in CI |
| `GITLEAKS_LICENSE` | Leave blank for now — free tier works without it | Gitleaks runs free on public repos |

For Semgrep token:
1. Go to semgrep.dev
2. Sign up free (use GitHub login — it connects automatically)
3. Go to **Settings → Tokens**
4. Create a token, copy it
5. Paste it as the `SEMGREP_APP_TOKEN` secret in GitHub

### Step 3 — Set Up Git on Your Local Machine

If you write code locally and push to GitHub:

```bash
git config --global user.name "Olamide Oladokun"
git config --global user.email "olamideoladokun150@gmail.com"
```

Clone your new repo:
```bash
git clone https://github.com/YOUR_USERNAME/vulnapi.git
cd vulnapi
```

---

## Part 3 — Setting Up Your Server

### Step 1 — Install Requirements on Your Server

SSH into your server and run:

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install PHP 8.2 and required extensions
sudo apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-mysql \
    php8.2-mbstring php8.2-xml php8.2-curl php8.2-zip php8.2-bcmath

# Install MySQL
sudo apt install -y mysql-server

# Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Install Nginx
sudo apt install -y nginx

# Verify everything installed correctly
php --version       # Should show PHP 8.2.x
composer --version  # Should show Composer 2.x
mysql --version     # Should show MySQL 8.x
```

### Step 2 — Create the Database

```bash
sudo mysql -u root -p
```

Inside MySQL:
```sql
CREATE DATABASE vulnapi;
CREATE USER 'vulnapi_user'@'localhost' IDENTIFIED BY 'StrongPassword123!';
GRANT ALL PRIVILEGES ON vulnapi.* TO 'vulnapi_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

Write down: `vulnapi_user` / `StrongPassword123!` — you need this in your `.env` file.

### Step 3 — Point Your Subdomain to the Server

In your domain's DNS settings, add an A record:

```
Type: A
Name: vulnapi
Value: YOUR_SERVER_IP_ADDRESS
TTL: 300
```

This makes `vulnapi.yourdomain.com` point to your server. Replace `yourdomain.com` with your actual domain.

### Step 4 — Set Up Nginx for the App

Create the Nginx config:
```bash
sudo nano /etc/nginx/sites-available/vulnapi
```

Paste this:
```nginx
server {
    listen 80;
    server_name vulnapi.yourdomain.com;
    root /var/www/vulnapi/public;
    index index.php;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

Enable it:
```bash
sudo ln -s /etc/nginx/sites-available/vulnapi /etc/nginx/sites-enabled/
sudo nginx -t       # Test for errors
sudo systemctl reload nginx
```

### Step 5 — Create the App Directory on the Server

```bash
sudo mkdir -p /var/www/vulnapi
sudo chown -R $USER:www-data /var/www/vulnapi
sudo chmod -R 755 /var/www/vulnapi
```

---

## Part 4 — Building the Laravel Application

Do this on your **local machine** (where you write code), not on the server.

### Step 1 — Create the Project

```bash
# Inside your cloned vulnapi folder
composer create-project laravel/laravel . --prefer-dist
```

The `.` means install here in the current folder, not in a subfolder.

### Step 2 — Install JWT Authentication

```bash
composer require php-open-source-saver/jwt-auth
```

Publish the config:
```bash
php artisan vendor:publish --provider="PHPOpenSourceSaver\JWTAuth\Providers\LaravelServiceProvider"
```

Generate the JWT secret key:
```bash
php artisan jwt:secret
```

This adds `JWT_SECRET=xxxxx` to your `.env` file automatically.

### Step 3 — Configure the User Model for JWT

Open `app/Models/User.php` and replace the entire file with:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use PHPOpenSourceSaver\JWTAuth\Contracts\JWTSubject;

class User extends Authenticatable implements JWTSubject
{
    use HasFactory, Notifiable;

    // ❌ VULNERABILITY V4 — Mass Assignment
    // We are NOT defining $fillable here, which means all fields
    // including 'role' can be set via $request->all()
    // The correct practice is to define $fillable explicitly
    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
    ];

    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    public function getJWTCustomClaims()
    {
        return [];
    }

    public function notes()
    {
        return $this->hasMany(Note::class);
    }
}
```

### Step 4 — Configure Auth to Use JWT

Open `config/auth.php` and change the `api` guard:

```php
'guards' => [
    'web' => [
        'driver' => 'session',
        'provider' => 'users',
    ],
    'api' => [
        'driver' => 'jwt',        // Change this from 'token' to 'jwt'
        'provider' => 'users',
    ],
],
```

### Step 5 — Create the Migrations

**Add a `role` column to the users table:**

Open `database/migrations/xxxx_create_users_table.php` and add this line inside the `up()` function, after the `password` line:

```php
$table->string('role')->default('user'); // 'user' or 'admin'
```

**Create the notes table:**

```bash
php artisan make:migration create_notes_table
```

Open the new migration file in `database/migrations/` and fill in `up()`:

```php
public function up(): void
{
    Schema::create('notes', function (Blueprint $table) {
        $table->id();
        $table->foreignId('user_id')->constrained()->onDelete('cascade');
        $table->string('title');
        $table->text('body');
        $table->timestamps();
    });
}
```

### Step 6 — Create the Note Model

```bash
php artisan make:model Note
```

Open `app/Models/Note.php`:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Note extends Model
{
    protected $fillable = ['user_id', 'title', 'body'];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
```

### Step 7 — Create the Controllers

```bash
php artisan make:controller AuthController
php artisan make:controller NoteController
php artisan make:controller AdminController
```

---

### Step 8 — Write AuthController (with Vulnerability V4 and V5)

Open `app/Http/Controllers/AuthController.php`:

```php
<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use PHPOpenSourceSaver\JWTAuth\Facades\JWTAuth;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|string|email|unique:users',
            'password' => 'required|string|min:6',
        ]);

        // ❌ VULNERABILITY V4 — Mass Assignment
        // $request->all() passes EVERY field from the request directly into create()
        // This includes the 'role' field, which is not in any $fillable list
        // because we never defined $fillable in the User model.
        // An attacker can set "role": "admin" in the request body
        // and create themselves an admin account.
        $user = User::create(array_merge(
            $request->all(),
            ['password' => Hash::make($request->password)]
        ));

        $token = JWTAuth::fromUser($user);

        return response()->json([
            'message' => 'User registered successfully',
            'user'    => $user,
            'token'   => $token,
        ], 201);
    }

    public function login(Request $request)
    {
        // ❌ VULNERABILITY V5 — No Rate Limiting
        // This endpoint has no throttle middleware.
        // An attacker can send unlimited login attempts per second
        // and brute-force any account's password.
        // The fix is to add throttle:5,1 middleware on the route.

        $credentials = $request->only('email', 'password');

        if (!$token = auth('api')->attempt($credentials)) {
            return response()->json(['error' => 'Invalid credentials'], 401);
        }

        return response()->json([
            'message' => 'Login successful',
            'token'   => $token,
            'user'    => auth('api')->user(),
        ]);
    }

    public function logout()
    {
        auth('api')->logout();
        return response()->json(['message' => 'Logged out successfully']);
    }

    public function me()
    {
        return response()->json(auth('api')->user());
    }
}
```

---

### Step 9 — Write NoteController (with Vulnerabilities V1 and V2)

Open `app/Http/Controllers/NoteController.php`:

```php
<?php

namespace App\Http\Controllers;

use App\Models\Note;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class NoteController extends Controller
{
    public function index()
    {
        // This one is fine — it correctly filters by the logged-in user
        $notes = Note::where('user_id', auth()->id())->get();
        return response()->json($notes);
    }

    public function store(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'body'  => 'required|string',
        ]);

        $note = Note::create([
            'user_id' => auth()->id(),
            'title'   => $request->title,
            'body'    => $request->body,
        ]);

        return response()->json($note, 201);
    }

    public function show($id)
    {
        // ❌ VULNERABILITY V2 — Insecure Direct Object Reference (IDOR)
        // We look up the note by ID alone, without checking that it belongs
        // to the currently authenticated user.
        // User A can request /api/notes/5 and if note 5 belongs to User B,
        // User A gets the full note back. No error, no check.
        $note = Note::findOrFail($id);
        return response()->json($note);
    }

    public function update(Request $request, $id)
    {
        // ❌ VULNERABILITY V2 — IDOR (same problem on update)
        // Any authenticated user can update any note by guessing its ID.
        $note = Note::findOrFail($id);

        $request->validate([
            'title' => 'sometimes|string|max:255',
            'body'  => 'sometimes|string',
        ]);

        $note->update($request->only(['title', 'body']));
        return response()->json($note);
    }

    public function destroy($id)
    {
        // ❌ VULNERABILITY V2 — IDOR (same problem on delete)
        // Any authenticated user can delete any note by guessing its ID.
        $note = Note::findOrFail($id);
        $note->delete();
        return response()->json(['message' => 'Note deleted']);
    }

    public function search(Request $request)
    {
        $keyword = $request->input('keyword');

        // ❌ VULNERABILITY V1 — SQL Injection
        // We are building a raw SQL query by concatenating the user's input
        // directly into the query string. There is zero sanitization.
        //
        // Normal request: GET /api/search?keyword=shopping
        // Returns notes where body contains "shopping" — seems fine.
        //
        // Malicious request: GET /api/search?keyword=%' OR '1'='1
        // The SQL becomes: SELECT * FROM notes WHERE body LIKE '%%' OR '1'='1%'
        // This returns EVERY note from EVERY user in the database.
        //
        // Even worse: GET /api/search?keyword=x' UNION SELECT id,email,password,4 FROM users--
        // This can dump the entire users table including password hashes.
        $notes = DB::select(
            "SELECT * FROM notes WHERE body LIKE '%" . $keyword . "%'"
        );

        return response()->json($notes);
    }
}
```

---

### Step 10 — Write AdminController (with Vulnerability V3)

Open `app/Http/Controllers/AdminController.php`:

```php
<?php

namespace App\Http\Controllers;

use App\Models\User;

class AdminController extends Controller
{
    public function listUsers()
    {
        // ❌ VULNERABILITY V3 — Broken Access Control
        // This route is protected by 'auth:api' middleware, which means
        // you must be logged in. But there is NO role check.
        // Any registered user — not just admins — can call this endpoint
        // and receive a full dump of every user's name, email, role,
        // and registration date.
        //
        // The fix requires creating an IsAdmin middleware that checks:
        // auth()->user()->role === 'admin'
        // and applying it to this route.
        $users = User::all();
        return response()->json($users);
    }
}
```

---

### Step 11 — Define All Routes

Open `routes/api.php` and replace everything with:

```php
<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\NoteController;
use App\Http\Controllers\AdminController;
use Illuminate\Support\Facades\Route;

// ──────────────────────────────────────────
// Public routes — no authentication required
// ──────────────────────────────────────────
Route::post('/register', [AuthController::class, 'register']);

// ❌ VULNERABILITY V5 — No rate limiting on login
// Should be: Route::middleware('throttle:5,1')->post(...)
// But we are intentionally NOT adding throttle here
Route::post('/login', [AuthController::class, 'login']);

// ──────────────────────────────────────────
// Protected routes — must be logged in
// ──────────────────────────────────────────
Route::middleware('auth:api')->group(function () {

    // Auth
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    // Notes
    Route::get('/notes', [NoteController::class, 'index']);
    Route::post('/notes', [NoteController::class, 'store']);
    Route::get('/notes/{id}', [NoteController::class, 'show']);
    Route::put('/notes/{id}', [NoteController::class, 'update']);
    Route::delete('/notes/{id}', [NoteController::class, 'destroy']);

    // Search — contains SQL injection
    Route::get('/search', [NoteController::class, 'search']);

    // ❌ VULNERABILITY V3 — Admin route has no role check
    // Only protected by auth:api (must be logged in)
    // Should also have IsAdmin middleware
    Route::get('/admin/users', [AdminController::class, 'listUsers']);

});
```

---

### Step 12 — Configure Your .env File

This is where Vulnerability V6 happens. Open your `.env` file and make sure it looks like this. **You will intentionally commit this file to Git in a test branch** so Gitleaks catches it.

```env
APP_NAME=VulnAPI
APP_ENV=production
APP_KEY=base64:WILL_BE_GENERATED_BY_ARTISAN
APP_DEBUG=true
APP_URL=https://vulnapi.yourdomain.com

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=vulnapi
DB_USERNAME=vulnapi_user
DB_PASSWORD=StrongPassword123!

JWT_SECRET=supersecretjwtkey_this_should_never_be_in_git_12345

# ❌ VULNERABILITY V6 — Hardcoded secrets about to be committed to Git
# Real developers do this accidentally all the time.
# Gitleaks in the pipeline will detect these patterns.
STRIPE_SECRET=sk_test_4eC39HqLyjWDarjtT1zdp7dc
MAIL_PASSWORD=MyEmailPassword123
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

Note: The Stripe key, AWS key, and mail password above are **fake example values** that match the patterns Gitleaks looks for. They will trigger the scanner exactly as real leaked credentials would.

---

## Part 5 — Deploying to Your Server

### Step 1 — Push Your Code to GitHub First

On your local machine, inside the vulnapi folder:

```bash
# Add all files including .env (intentionally, for the Gitleaks demo)
git add .
git commit -m "feat: initial VulnAPI with intentional vulnerabilities for DevSecOps demo"
git push origin main
```

### Step 2 — Pull the Code on Your Server

SSH into your server:

```bash
cd /var/www
git clone https://github.com/YOUR_USERNAME/vulnapi.git
cd vulnapi
```

### Step 3 — Install Dependencies on the Server

```bash
composer install --optimize-autoloader
```

### Step 4 — Set Up the .env on the Server

```bash
cp .env.example .env
php artisan key:generate
php artisan jwt:secret
```

Then open `.env` and fill in your actual database credentials:

```bash
nano .env
```

Set:
```
DB_DATABASE=vulnapi
DB_USERNAME=vulnapi_user
DB_PASSWORD=StrongPassword123!
APP_URL=https://vulnapi.yourdomain.com
```

### Step 5 — Run Migrations and Set Permissions

```bash
php artisan migrate
sudo chown -R www-data:www-data /var/www/vulnapi/storage
sudo chmod -R 775 /var/www/vulnapi/storage
```

### Step 6 — Test the API is Live

```bash
curl https://vulnapi.yourdomain.com/api/register \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@test.com","password":"password123"}'
```

You should get back a JSON response with a token. If you do, the app is live.

### Step 7 — (Optional but Recommended) Set Up SSL

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d vulnapi.yourdomain.com
```

Follow the prompts. This gives you HTTPS for free. ZAP works better with HTTPS and it looks more professional.

---

## Part 6 — The Pipeline (GitHub Actions)

Create this folder structure in your project:

```
.github/
└── workflows/
    └── devsecops.yml
```

```bash
mkdir -p .github/workflows
touch .github/workflows/devsecops.yml
```

### The Complete Pipeline YAML

Open `.github/workflows/devsecops.yml` and paste this entire file:

```yaml
name: "SecurePipe — DevSecOps CI/CD Pipeline"

# ─────────────────────────────────────────────────────────────
# This pipeline runs on every push and every pull request.
# It has four stages: SAST, SCA, Secrets, DAST.
# The DAST stage only runs if the first three all pass.
# If any stage fails, the whole pipeline is marked as failed.
# ─────────────────────────────────────────────────────────────

on:
  push:
    branches: [ main, develop, "fix/*" ]
  pull_request:
    branches: [ main ]

jobs:

  # ═══════════════════════════════════════════════════════════
  # STAGE 1 — SAST (Static Application Security Testing)
  # Tool: Semgrep
  # What it does: Reads your PHP source code without running it.
  # Looks for patterns that match known vulnerability signatures.
  # Will catch: SQL injection in NoteController, mass assignment
  # in AuthController, and other dangerous coding patterns.
  # ═══════════════════════════════════════════════════════════
  sast:
    name: "SAST — Semgrep Code Analysis"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Semgrep SAST scan
        uses: semgrep/semgrep-action@v1
        with:
          config: >-
            p/php
            p/owasp-top-ten
            p/sql-injection
            p/laravel
        env:
          SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}

      # This step saves the Semgrep findings as a downloadable report
      # you can attach to your case study
      - name: Upload Semgrep results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: semgrep-report
          path: semgrep.sarif
          if-no-files-found: ignore

  # ═══════════════════════════════════════════════════════════
  # STAGE 2 — SCA (Software Composition Analysis)
  # Tool: Composer Audit (built into Composer 2+, no install needed)
  # What it does: Checks every package in your composer.lock file
  # against the PHP Security Advisories database.
  # Will catch: Any Laravel packages or dependencies with known
  # published CVEs (Common Vulnerabilities and Exposures).
  # ═══════════════════════════════════════════════════════════
  sca:
    name: "SCA — Dependency Vulnerability Audit"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up PHP 8.2
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
          tools: composer

      - name: Install PHP dependencies
        run: composer install --no-interaction --prefer-dist

      - name: Audit dependencies for known CVEs
        run: |
          composer audit --format=json | tee composer-audit-report.json || true
          composer audit
        # The first line saves a JSON report for your documentation.
        # The second line runs again and exits with error code if issues found,
        # which causes this job to fail correctly.

      - name: Upload dependency audit report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: composer-audit-report
          path: composer-audit-report.json
          if-no-files-found: ignore

  # ═══════════════════════════════════════════════════════════
  # STAGE 3 — Secrets Detection
  # Tool: Gitleaks
  # What it does: Scans your ENTIRE Git commit history (not just
  # the latest code) for patterns that look like secrets:
  # API keys, passwords, JWT secrets, AWS credentials, etc.
  # Will catch: The fake Stripe key, AWS key, and mail password
  # you deliberately added to your .env and committed.
  # ═══════════════════════════════════════════════════════════
  secrets:
    name: "Secrets — Gitleaks History Scan"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository with full history
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          # fetch-depth: 0 means pull the ENTIRE git history,
          # not just the latest commit. Gitleaks needs this to
          # scan all commits, including old ones where a secret
          # may have been added and later "deleted."
          # Deleting a file from Git does not remove it from history.
          # Gitleaks will still find it.

      - name: Run Gitleaks secrets scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # GITHUB_TOKEN is automatically provided by GitHub Actions.
          # You do not need to create this secret yourself.

  # ═══════════════════════════════════════════════════════════
  # STAGE 4 — DAST (Dynamic Application Security Testing)
  # Tool: OWASP ZAP
  # What it does: Sends real HTTP requests to your LIVE running
  # application at vulnapi.yourdomain.com and probes it for
  # vulnerabilities by actually attacking it.
  # This stage only runs if Stages 1, 2, and 3 all pass.
  # Will catch: Missing security headers, exposed error messages,
  # directory traversal, and other issues only visible at runtime.
  #
  # NOTE: ZAP's baseline scan is PASSIVE — it does not send attack
  # payloads. It observes and reports. This is safe to run against
  # your live server. If you want the active (aggressive) scan,
  # use zaproxy/action-full-scan — but only on a test environment.
  # ═══════════════════════════════════════════════════════════
  dast:
    name: "DAST — OWASP ZAP Live Scan"
    runs-on: ubuntu-latest
    needs: [sast, sca, secrets]
    # ↑ This line makes DAST depend on the other three stages.
    # If any of them fail, DAST is skipped entirely.
    # This is intentional — no point scanning a live app if
    # the code is already known to be vulnerable.

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run OWASP ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.12.0
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          docker_name: 'ghcr.io/zaproxy/zaproxy:stable'
          target: 'https://vulnapi.yourdomain.com'
          # ↑ Replace this with your actual domain
          rules_file_name: '.zap/rules.tsv'
          fail_action: false
          # fail_action: false means ZAP findings create a report
          # but do not fail the pipeline. This is correct for a
          # passive scan — you want to see what it finds without
          # blocking your deployment. Change to true if you want
          # ZAP findings to block merges.
          cmd_options: '-a'
          artifact_name: 'zap-baseline-report'

      - name: Upload ZAP HTML Report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: zap-dast-report
          path: report_html.html
```

### Create the ZAP Rules File

ZAP needs a rules file to know which alerts to ignore (some are informational noise). Create:

```bash
mkdir -p .zap
touch .zap/rules.tsv
```

Open `.zap/rules.tsv` and paste:

```tsv
10096	IGNORE	(Timestamp Disclosure - Unix)
10027	IGNORE	(Information Disclosure - Suspicious Comments)
```

These two are always flagged on Laravel apps and are not real vulnerabilities. Everything else ZAP finds should stay visible.

### Push the Pipeline

```bash
git add .github/ .zap/
git commit -m "ci: add DevSecOps pipeline — Semgrep, Gitleaks, Composer Audit, ZAP"
git push origin main
```

Now go to your GitHub repo → **Actions** tab. You will see the pipeline running.

---

## Part 7 — Watching the Pipeline Fail

After your first push with the vulnerable code:

Go to **GitHub → Your Repo → Actions**. Click on the running workflow. You will see four jobs running.

### What You Will See

**Semgrep (SAST) — Will Fail ❌**

Semgrep reads `NoteController.php` and finds the raw SQL concatenation on the search endpoint. It will show something like:

```
app/Http/Controllers/NoteController.php
Line 67: php.laravel.security.audit.raw-query-
         string-variable.raw-query-string-variable
         Detected a SQL injection risk using raw queries
```

Click into the Semgrep job → scroll to the scan output → screenshot the finding with the file name and line number visible. Download the `semgrep-report` artifact from the Actions run for your documentation.

**Gitleaks (Secrets) — Will Fail ❌**

Gitleaks scans every commit and finds the `.env` file you committed. It will flag:

```
Finding: STRIPE_SECRET
Secret: sk_test_4eC39HqLyjWDarjtT1zdp7dc
File: .env
Commit: abc1234...
Rule: stripe-access-token
```

Screenshot the Gitleaks failure output. This is your proof that secrets management matters — even "deleting" the file later would not remove it from Git history.

**Composer Audit (SCA) — May Pass or Warn ⚠️**

This depends on whether your installed packages have known CVEs. If they all pass, that is fine — screenshot the green result. It still proves the check is running. If it finds something, even better — screenshot it.

**DAST (ZAP) — Skipped ⏭️**

Because Semgrep and Gitleaks failed, the DAST stage is skipped. This is correct behaviour. Screenshot the skipped status.

**Take a full screenshot of the Actions summary page** showing the four jobs with their statuses. This is your "before" screenshot.

---

## Part 8 — Breaking the App Manually with Burp Suite

While the pipeline is failing, also manually exploit each vulnerability using Burp Suite. This proves you understand what you built — not just that a tool caught it.

### Setup Burp Suite

1. Download Burp Suite Community Edition from portswigger.net — it is free
2. Open it and go to **Proxy → Proxy Settings**
3. Confirm it is listening on `127.0.0.1:8080`
4. In your browser, set HTTP proxy to `127.0.0.1` port `8080`
5. Visit `https://vulnapi.yourdomain.com` in your browser
6. In Burp → **Proxy → Intercept** → click **Open Browser** to use Burp's built-in browser (easiest, no certificate setup needed)

### Create Test Accounts First

Using curl or Postman, create two users:

**User A:**
```bash
curl -X POST https://vulnapi.yourdomain.com/api/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@test.com","password":"password123"}'
```

Save the token from the response. Create a note for Alice:
```bash
curl -X POST https://vulnapi.yourdomain.com/api/notes \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ALICE_TOKEN_HERE" \
  -d '{"title":"Alice Private Note","body":"This is Alice secret diary entry"}'
```

**User B:**
```bash
curl -X POST https://vulnapi.yourdomain.com/api/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Bob","email":"bob@test.com","password":"password123"}'
```

Create a note for Bob and note the ID (it will be in the response, probably ID 2):
```bash
curl -X POST https://vulnapi.yourdomain.com/api/notes \
  -H "Authorization: Bearer BOB_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"title":"Bob Secret Note","body":"This is Bobs private banking information"}'
```

---

### Manual Exploit 1 — SQL Injection

**Goal: Read ALL notes from ALL users while logged in as Alice only.**

In Burp Suite → **Repeater** tab → click the **+** to add a new tab.

Set method to GET and enter:

```
GET /api/search?keyword=%25%27+OR+%271%27%3D%271 HTTP/2
Host: vulnapi.yourdomain.com
Authorization: Bearer ALICE_TOKEN_HERE
```

The keyword decodes to: `%' OR '1'='1`

The raw SQL in your code becomes:
```sql
SELECT * FROM notes WHERE body LIKE '%%' OR '1'='1%'
```

Since `'1'='1'` is always true, this returns every row in the notes table from every user.

**Click Send.** You will see both Alice's notes AND Bob's notes in the response — even though you are logged in as Alice and should only see Alice's notes.

Screenshot the Repeater window showing:
- The request at the top
- The response at the bottom containing notes from multiple users
- Make sure the URL with the injection payload is visible

---

### Manual Exploit 2 — IDOR (Accessing Bob's Note as Alice)

**Goal: Read Bob's note while authenticated as Alice.**

You noted that Bob's note has ID 2 (or whatever ID the API returned). In Burp Repeater:

```
GET /api/notes/2 HTTP/2
Host: vulnapi.yourdomain.com
Authorization: Bearer ALICE_TOKEN_HERE
```

Click Send. You get Bob's full note back — title, body, user_id, everything.

Screenshot showing Alice's token in the Authorization header, and Bob's note content in the response.

---

### Manual Exploit 3 — Admin Route (No Role Check)

**Goal: Dump all users while logged in as a normal user.**

Alice is a regular user, not an admin. Send:

```
GET /api/admin/users HTTP/2
Host: vulnapi.yourdomain.com
Authorization: Bearer ALICE_TOKEN_HERE
```

You get back a full list of every user registered in the app — names, emails, roles, timestamps.

Screenshot showing the full user list returned with Alice's regular-user token.

---

### Manual Exploit 4 — Mass Assignment (Register as Admin)

**Goal: Create an admin account by exploiting the register endpoint.**

In Burp Repeater, switch to POST:

```
POST /api/register HTTP/2
Host: vulnapi.yourdomain.com
Content-Type: application/json

{
    "name": "Evil Hacker",
    "email": "hacker@evil.com",
    "password": "hacked123",
    "role": "admin"
}
```

Click Send. You get back the new user object. Look at the `role` field in the response. It says `admin`.

Now use the hacker's token to hit `/api/admin/users`. It works.

Screenshot the register request with the extra `role` field, and the response showing `"role": "admin"`.

---

### Manual Exploit 5 — Brute Force (No Rate Limiting)

**Goal: Show that the login endpoint accepts unlimited requests.**

In Burp Suite → **Intruder** tab.

1. Send your login request to Intruder (right-click in Proxy → Send to Intruder)
2. Go to **Positions** tab
3. Click **Clear §**
4. Highlight the password value and click **Add §**
5. Go to **Payloads** tab
6. Set Payload Type to **Simple List**
7. Add 20 random passwords in the list (wrong ones), then add the real one last
8. Click **Start Attack**

Watch all 20 requests go through immediately with no throttling. The server responds to each one without slowing down or blocking.

Screenshot the Intruder attack results table showing all requests completed with response codes (401 for wrong passwords, 200 for the correct one) — with no rate limiting happening.

---

## Part 9 — Fixing Everything

Now create a new branch for your fixes:

```bash
git checkout -b fix/security-hardening
```

### Fix 1 — SQL Injection

In `NoteController.php`, replace the entire `search` method:

```php
public function search(Request $request)
{
    $keyword = $request->input('keyword');

    // ✅ FIXED: Using Eloquent's query builder with parameter binding.
    // Laravel automatically escapes the keyword value, making injection impossible.
    // Also added user_id filter so users can only search their OWN notes.
    $notes = Note::where('user_id', auth()->id())
                 ->where('body', 'LIKE', '%' . $keyword . '%')
                 ->get();

    return response()->json($notes);
}
```

### Fix 2 — IDOR on All Note Methods

Replace `show`, `update`, and `destroy` in `NoteController.php`:

```php
public function show($id)
{
    // ✅ FIXED: Added where('user_id', auth()->id()) constraint.
    // If the note exists but belongs to another user, this returns 404.
    // The attacker learns nothing — not even whether the note exists.
    $note = Note::where('id', $id)
                ->where('user_id', auth()->id())
                ->firstOrFail();

    return response()->json($note);
}

public function update(Request $request, $id)
{
    // ✅ FIXED: Same ownership check before allowing update.
    $note = Note::where('id', $id)
                ->where('user_id', auth()->id())
                ->firstOrFail();

    $request->validate([
        'title' => 'sometimes|string|max:255',
        'body'  => 'sometimes|string',
    ]);

    $note->update($request->only(['title', 'body']));
    return response()->json($note);
}

public function destroy($id)
{
    // ✅ FIXED: Same ownership check before allowing deletion.
    $note = Note::where('id', $id)
                ->where('user_id', auth()->id())
                ->firstOrFail();

    $note->delete();
    return response()->json(['message' => 'Note deleted']);
}
```

### Fix 3 — Admin Role Check

Create a middleware:

```bash
php artisan make:middleware IsAdmin
```

Open `app/Http/Middleware/IsAdmin.php`:

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class IsAdmin
{
    public function handle(Request $request, Closure $next)
    {
        // ✅ Check that the authenticated user has the admin role.
        // If not, return 403 Forbidden — do not reveal any data.
        if (auth()->check() && auth()->user()->role === 'admin') {
            return $next($request);
        }

        return response()->json([
            'error' => 'Forbidden — admin access required'
        ], 403);
    }
}
```

Register it in `bootstrap/app.php` (Laravel 11) or `app/Http/Kernel.php` (Laravel 10):

For **Laravel 11**, open `bootstrap/app.php` and add inside the `withMiddleware` call:
```php
$middleware->alias([
    'isAdmin' => \App\Http\Middleware\IsAdmin::class,
]);
```

Update `routes/api.php` admin route:
```php
// ✅ FIXED: Now requires both auth AND admin role
Route::middleware(['auth:api', 'isAdmin'])->get('/admin/users', [AdminController::class, 'listUsers']);
```

### Fix 4 — Mass Assignment

In `app/Models/User.php`, add `$fillable`:

```php
// ✅ FIXED: Explicitly list the only fields that can be mass-assigned.
// 'role' is deliberately NOT in this list.
// Even if an attacker sends "role": "admin" in the request, it is ignored.
protected $fillable = [
    'name',
    'email',
    'password',
];
```

In `AuthController.php`, update the register method:

```php
// ✅ FIXED: Use only() instead of all() to whitelist safe fields explicitly.
$user = User::create([
    'name'     => $request->name,
    'email'    => $request->email,
    'password' => Hash::make($request->password),
    // 'role' is not here — it defaults to 'user' from the migration
]);
```

### Fix 5 — Rate Limiting

In `routes/api.php`, update the login route:

```php
// ✅ FIXED: 5 login attempts per 1 minute per IP address.
// After 5 failed attempts, the client receives 429 Too Many Requests.
// Laravel handles this automatically with the throttle middleware.
Route::middleware('throttle:5,1')->post('/login', [AuthController::class, 'login']);
```

### Fix 6 — Hardcoded Secrets

First, add `.env` to `.gitignore` if it is not already there:

Open `.gitignore` and confirm this line exists:
```
.env
```

Rotate your secrets — since they were committed to Git (even fake ones), treat them as compromised. The fake values you used do not matter, but document that in a real scenario you would:
1. Invalidate the leaked keys immediately in each service's dashboard
2. Generate new keys
3. Store them only in GitHub Actions Secrets or your server's `.env` (never in code)

Create `.env.example` with placeholder values for developers:

```env
APP_NAME=VulnAPI
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://yourdomain.com

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=vulnapi
DB_USERNAME=
DB_PASSWORD=

JWT_SECRET=

# Do NOT put real values here. Use your server .env or CI/CD secrets.
STRIPE_SECRET=
MAIL_PASSWORD=
AWS_SECRET_ACCESS_KEY=
```

Commit `.env.example` but make sure `.env` is in `.gitignore`.

---

### Push Your Fixes and Open a Pull Request

```bash
git add .
git commit -m "fix: remediate all six security vulnerabilities

- V1: Replace raw SQL with Eloquent query builder (SQLi fix)
- V2: Add user_id ownership check to all note endpoints (IDOR fix)
- V3: Create IsAdmin middleware, apply to admin route (access control fix)
- V4: Add \$fillable to User model, use only() in register (mass assignment fix)
- V5: Add throttle:5,1 middleware to login route (rate limiting fix)
- V6: Add .env to .gitignore, create .env.example (secrets fix)

All fixes verified against OWASP Top 10 categories."

git push origin fix/security-hardening
```

On GitHub → **Pull Requests** → **New Pull Request** → base: `main` ← compare: `fix/security-hardening`

Watch the Actions pipeline run on your PR. This time:

- Semgrep passes ✅ (no more raw SQL)
- Composer Audit passes ✅
- Gitleaks passes ✅ (the `.env` is no longer being committed)
- ZAP runs and reports findings ✅

Screenshot the green pipeline. Merge the PR.

**Deploy the fixes to your server:**

```bash
# On your server
cd /var/www/vulnapi
git pull origin main
composer install --optimize-autoloader
php artisan migrate
```

---

## Part 10 — Writing the Case Study

Create `security-report/REPORT.md` in your repo. This file is what you link on your portfolio. Write it like a real penetration test report.

```markdown
# VulnAPI Security Assessment Report
**Project:** SecurePipe DevSecOps Demo  
**Assessor:** Olamide Oladokun  
**Date:** [Today's date]  
**Scope:** https://vulnapi.yourdomain.com  
**Methodology:** OWASP Testing Guide v4, OWASP Top 10 2021  

---

## Executive Summary

VulnAPI was designed as a controlled security exercise to demonstrate 
the complete DevSecOps lifecycle. Six real-world vulnerabilities were 
intentionally introduced across authentication, authorization, and data 
access layers. Each was detected using automated tooling in a GitHub 
Actions CI/CD pipeline, manually exploited to confirm impact, and then 
remediated with documented code changes.

The automated pipeline catches critical vulnerabilities before code 
reaches production — a practice known as shifting security left.

---

## Pipeline Architecture

[Insert screenshot of your GitHub Actions pipeline diagram]

| Stage | Tool | Type | Trigger |
|-------|------|------|---------|
| SAST | Semgrep | Static Analysis | Every push |
| SCA | Composer Audit | Dependency Scan | Every push |
| Secrets | Gitleaks | Secret Detection | Every push (full history) |
| DAST | OWASP ZAP | Dynamic Scan | After stages 1–3 pass |

---

## Findings Summary

| ID | Title | OWASP | Severity | Detection | Status |
|----|-------|-------|----------|-----------|--------|
| V1 | SQL Injection in /search | A03 | Critical | Semgrep | Fixed |
| V2 | IDOR on Note Endpoints | A01 | High | Manual (Burp Suite) | Fixed |
| V3 | Missing Admin Role Check | A01 | High | Manual (Burp Suite) | Fixed |
| V4 | Mass Assignment in /register | A08 | High | Semgrep | Fixed |
| V5 | No Rate Limiting on /login | A04 | Medium | ZAP + Manual | Fixed |
| V6 | Secrets Committed to Git | A02 | Critical | Gitleaks | Fixed |

---

## Detailed Findings

### V1 — SQL Injection (Critical)

**Location:** `app/Http/Controllers/NoteController.php` — search()  
**OWASP Category:** A03:2021 – Injection  
**Detection:** Semgrep flagged the raw string concatenation on line 67  

**Vulnerable Code:**
```php
$notes = DB::select(
    "SELECT * FROM notes WHERE body LIKE '%" . $keyword . "%'"
);
```

**Exploitation:** Sending `%' OR '1'='1` as the keyword caused the query 
to return all notes from all users in the database, bypassing the 
intended per-user data isolation completely.

**Evidence:** [Insert Burp Suite screenshot]  
**Semgrep Finding:** [Insert screenshot]  

**Remediation:**
```php
$notes = Note::where('user_id', auth()->id())
             ->where('body', 'LIKE', '%' . $keyword . '%')
             ->get();
```

Eloquent uses PDO prepared statements, which separate data from SQL 
structure. User input cannot modify the query logic.

---

[Continue this format for V2 through V6...]

---

## Pipeline Results

### Before Fixes
[Insert screenshot of failed pipeline — all red]

### After Fixes  
[Insert screenshot of green pipeline]

---

## Key Takeaways

**Automated scanning catches what code review misses.** Semgrep found 
the SQL injection on the first scan before the app was even deployed.

**Secrets in Git history are permanent.** Even after deleting the .env 
file from the repository, Gitleaks found the credentials in the commit 
history. The only real fix is to treat them as compromised and rotate them.

**IDOR is invisible to static scanners.** Burp Suite manual testing 
found the IDOR vulnerabilities that Semgrep could not detect, because 
authorization logic errors require understanding the application's 
intended behaviour — not just its code patterns.

**Defense in depth.** No single tool catches everything. The combination 
of SAST + SCA + Secrets + DAST + manual testing provides coverage across 
the full vulnerability surface.
```

---

## Part 11 — What to Put on Your Portfolio

### Project Card Description

**Title:** SecurePipe — DevSecOps CI/CD Security Pipeline

**Description:**
Built a deliberately vulnerable Laravel REST API (VulnAPI) and wrapped it in a complete DevSecOps pipeline using GitHub Actions. The pipeline runs static code analysis with Semgrep, dependency vulnerability scanning with Composer Audit, secrets detection with Gitleaks, and dynamic application security testing with OWASP ZAP against the live server — all automated on every code push. Six OWASP Top 10 vulnerabilities were introduced, detected by the pipeline, manually exploited with Burp Suite to confirm real-world impact, then fully remediated. The entire process is documented as a penetration test report.

**Tags to show:**
`Laravel` `PHP` `GitHub Actions` `Semgrep` `OWASP ZAP` `Gitleaks` `Burp Suite` `OWASP Top 10` `DevSecOps` `AppSec` `Penetration Testing`

**Links on the card:**
- GitHub repository (public)
- Link directly to `security-report/REPORT.md`
- Live URL: `https://vulnapi.yourdomain.com` (the fixed version)

---

## Summary — The Order to Do Everything

1. Create GitHub repo and add Semgrep token to secrets
2. Set up your server (PHP, MySQL, Nginx, subdomain)
3. Build the Laravel app locally with all six vulnerabilities written in
4. Write the pipeline YAML
5. Push everything to GitHub (including the .env with fake secrets — intentionally)
6. Watch the pipeline fail and screenshot every stage
7. Manually exploit all six vulnerabilities with Burp Suite and screenshot each one
8. Create the fix branch, fix all six issues, push, open PR
9. Watch the pipeline go green, screenshot it
10. Merge, deploy fixes to server
11. Write the case study report
12. Add to your portfolio

---

*Olamide Oladokun — Full-Stack Developer & Application Security Engineer*  
*olamideoladokun150@gmail.com · Lagos, Nigeria*
