# Violation & Incident Feature — Implementation Plan

## Flow

```
Tap FAB / "Beri Pelanggaran"
  │
  ├── ► Beri Violation        ─┐
  │                             │ Bottom Sheet pilihan
  ├── ► Beri Incident          ─┘
  │                             │
  ▼                             ▼
  ┌─ ViolationFormSheet ─────────────────┐
  │  User / Karyawan    [search & select] │
  │  Level             [ 1 ] [ 2 ] [ 3 ]  │ ← segmented, low→high
  │  Tipe Pelanggaran  [dropdown ▼]       │ ← violation_categories
  │  Sub Tipe          [dropdown ▼]       │ ← violation_subcategories
  │  ──────────────────────────────────   │
  │  Judul Pelanggaran [text field]       │
  │  Deskripsi         [textarea]         │
  │  Lokasi            [text field]       │
  │  Masa Berlaku      [date picker]      │
  │  Status            [Aktif / Selesai]  │
  │  Sanksi / Tindakan [text field]       │
  │  Foto              [image picker]     │
  │  ┌────────────────────────┐           │
  │  │      SIMPAN DATA       │           │
  │  └────────────────────────┘           │
  └────────────────────────────────────────┘
```

---

## Navigation Map

```
Profile > Workspace
  │
  ├── "Violation & Incident" ──► ViolationManagementScreen
  │     ├── List all (filter by type + status)
  │     ├── FAB → pilih "Beri Violation" / "Beri Incident"
  │     │         → ViolationFormSheet (type pre-set)
  │     └── Tap card → ViolationFormSheet (edit mode)
  │
  User Management
  │   └── [tap user] ──► UserProfileViewScreen
  │         └── Tab "Pelanggaran"
  │               ├── List violations user ini (existing, read-only)
  │               └── FAB → bottom sheet "Beri Violation"/"Beri Incident"
  │                         → ViolationFormSheet (user pre-filled)
```

---

## Backend — Files to Create/Modify

| # | File | Action | Description |
|---|------|--------|-------------|
| 1 | `be/database/migrations/2026_05_26_000001_create_violation_categories_tables.php` | **CREATE** | Create `violation_categories` + `violation_subcategories` tables |
| 2 | `be/database/migrations/2026_05_26_000002_add_type_level_category_to_user_violations.php` | **CREATE** | Add `violation_category`, `violation_subcategory`, `type`, `level` to `user_violations` |
| 3 | `be/app/Models/ViolationCategory.php` | **CREATE** | Model with `hasMany(Subcategory)` |
| 4 | `be/app/Models/ViolationSubcategory.php` | **CREATE** | Model with `belongsTo(Category)` |
| 5 | `be/app/Models/UserViolation.php` | **MODIFY** | Add `$fillable` fields + `$casts` for `level` |
| 6 | `be/app/Http/Controllers/API/ViolationCategoryController.php` | **CREATE** | Full CRUD for categories + subcategories (same pattern as HazardCategoryController) |
| 7 | `be/app/Http/Controllers/API/ViolationController.php` | **CREATE** | Extract violation CRUD from AuthController; add `index()`, `store()`, `show()`, `update()`, `destroy()` |
| 8 | `be/app/Http/Controllers/API/AuthController.php` | **MODIFY** | Remove 4 violation methods (`adminViolationsIndex`, `adminStoreViolation`, `adminUpdateViolation`, `adminDestroyViolation`) |
| 9 | `be/routes/api.php` | **MODIFY** | Add violation-category routes; update violation routes to point to ViolationController |
| 10 | `be/database/seeders/ViolationCategorySeeder.php` | **CREATE** | Seed default categories |

### Database Schema

```sql
violation_categories (
    id          BIGINT PK AUTO_INCREMENT,
    name        VARCHAR(255) NOT NULL,
    code        VARCHAR(50) NULL,
    created_at  TIMESTAMP,
    updated_at  TIMESTAMP
)

violation_subcategories (
    id            BIGINT PK AUTO_INCREMENT,
    category_id   BIGINT FK → violation_categories(id) ON DELETE CASCADE,
    name          VARCHAR(255) NOT NULL,
    abbreviation  VARCHAR(50) NULL,
    description   TEXT NULL,
    is_active     BOOLEAN DEFAULT true,
    created_at    TIMESTAMP,
    updated_at    TIMESTAMP
)

-- Added to user_violations:
-- violation_category      VARCHAR(100) NULL  (stores category code)
-- violation_subcategory   VARCHAR(100) NULL  (stores subcategory name)
-- type                    ENUM('Violation','Incident') DEFAULT 'Violation'
-- level                   TINYINT UNSIGNED DEFAULT 1  (1=low, 2=med, 3=high)
```

### Seeder Data: Violation Categories

| Category | Code | Subcategories |
|----------|------|--------------|
| Keselamatan Kerja | K3 | Tidak Pakai APD, Alat Rusak/Layak Pakai, Area Kerja Tidak Aman |
| Kedisiplinan | DSP | Terlambat/Izin Tidak Sah, Tidak Patuh Prosedur, Meninggalkan Tugas |
| Operasional | OPS | SOP Dilanggar, Dokumen Tidak Lengkap, Operasi Tanpa Izin |
| Lingkungan | LHK | Buang Limbah Sembarangan, Pencemaran Lingkungan, Kebersihan Area |
| Lalu Lintas | LL | Parkir Sembarangan, Berkendara Berbahaya, Tidak Punya SIM |

---

## Frontend — Files to Create/Modify

| # | File | Action | Description |
|---|------|--------|-------------|
| 1 | `fe/lib/services/violation_service.dart` | **MODIFY** | Add fields to `ViolationItem`; add `getViolationCategories()`, `ViolationCategoryData`, `ViolationSubcategoryData` |
| 2 | `fe/lib/models/profile_model.dart` | **MODIFY** | Add `violationCategory`, `violationSubcategory`, `type`, `level` to `UserViolation` |
| 3 | `fe/lib/widgets/violation_form_sheet.dart` | **CREATE** | Extract & enhance form from violation_management.dart — add level, category, subcategory fields; accept `initialType` and `preSelectedUser` params |
| 4 | `fe/lib/widgets/violation_type_picker.dart` | **CREATE** | Reusable bottom sheet widget: "Beri Violation" / "Beri Incident" choices |
| 5 | `fe/lib/screens/violation_management.dart` | **MODIFY** | Update FAB to show Violation/Incident options; update form to use extracted widget; add type filter chips; show level & type badges on cards |
| 6 | `fe/lib/screens/violation_detail_screen.dart` | **MODIFY** | Display level, type, category, subcategory in detail view |
| 7 | `fe/lib/screens/user_profile_view_screen.dart` | **MODIFY** | Add FAB in Pelanggaran tab → type picker → form (user pre-filled) |
| 8 | `fe/lib/screens/profile_screen.dart` | **MODIFY** | Rename "User Violations" to "Violation & Incident" |

### ViolationFormSheet — Constructor Params

```dart
class ViolationFormSheet extends StatefulWidget {
  final ViolationItem? item;                    // null = create, non-null = edit
  final String initialType;                     // 'Violation' / 'Incident'
  final Map<String, dynamic>? preSelectedUser;  // pre-filled user (from profile)
  final VoidCallback onSuccess;
}
```

### API Payload (create/update)

```json
{
  "title": "Tidak memakai helm",
  "violation_category": "K3",
  "violation_subcategory": "Tidak Pakai APD",
  "type": "Violation",
  "level": 2,
  "description": "...",
  "location": "Pit A",
  "expired_at": "2026-12-31",
  "status": "Aktif",
  "sanction": "SP1",
  "file_url": "https://supabase.storage/..."
}
```

---

## Execution Order

| Step | Area | Action | Depends On |
|------|------|--------|------------|
| 1 | BE | Migration: create violation_categories + subcategories tables | — |
| 2 | BE | Migration: add columns to user_violations | — |
| 3 | BE | Models: ViolationCategory + ViolationSubcategory | 1 |
| 4 | BE | Update Model: UserViolation (fillable + casts) | 2 |
| 5 | BE | Controller: ViolationCategoryController | 3 |
| 6 | BE | Controller: ViolationController (extract from AuthController) | 4 |
| 7 | BE | Update AuthController: remove violation methods | 6 |
| 8 | BE | Routes: update api.php | 5, 6 |
| 9 | BE | Seeder: ViolationCategorySeeder | 1 |
| 10 | BE | Run `php artisan migrate && php artisan db:seed` | 9 |
| 11 | FE | Model: Update violation_service.dart | — |
| 12 | FE | Model: Update profile_model.dart | — |
| 13 | FE | Widget: Create violation_form_sheet.dart | 11 |
| 14 | FE | Widget: Create violation_type_picker.dart | — |
| 15 | FE | Screen: Update violation_management.dart | 13, 14 |
| 16 | FE | Screen: Update violation_detail_screen.dart | 12 |
| 17 | FE | Screen: Update user_profile_view_screen.dart | 13, 14 |
| 18 | FE | Screen: Update profile_screen.dart (rename menu) | — |
