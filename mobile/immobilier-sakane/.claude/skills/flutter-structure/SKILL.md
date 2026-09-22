---
name: flutter-structure
description: Use this skill for any Flutter mobile task in the immobilier project. Guides Claude to follow the established architecture: repository pattern, cubit state management, go_router navigation, and feature-based folder structure.
---

# Flutter Mobile App Structure Guide

## Project Overview
A Flutter real estate booking management app that consumes a Laravel REST API.
The app uses **Cubit** for state management, **go_router** for navigation, and a **custom Repository pattern** for data access.

---

## Core Architecture

### Dependency Injection
The app uses a custom `Dependencies` container (NOT GetIt or Provider):
```dart
// Register
Dependencies.put<MyService>(MyService());

// Retrieve
MyService service = Dependencies.get<MyService>();
```
All dependencies are registered in `main.dart` inside `prepareDependencies()`.
When adding a new repository or service, always register it there.

### App Entry Points
- `main.dart` → app entry, calls `prepareDependencies()`, runs `MyApp`
- `config.dart` → global constants: `baseUrl`, `baseUrlApiVersion`, `packageName`, `version`
- `routes.dart` → all app routes using `go_router`

---

## Folder Structure
immobilier/lib/
├── main.dart
├── config.dart
├── routes.dart
├── core/
│   ├── constants/
│   │   ├── enums/
│   │   │   ├── app_status.dart       ← AppStatus enum (loading, success, error...)
│   │   │   └── permissions.dart
│   │   ├── app_colors.dart           ← AppColors.primaryColor etc.
│   │   ├── app_images.dart
│   │   ├── app_strings.dart          ← AppStrings.error, AppStrings.success...
│   │   └── charts_colors.dart
│   ├── dependencies/
│   │   └── dependencies.dart         ← custom DI container
│   ├── extensions/                   ← extensions on DateTime, String, int, double...
│   ├── services/
│   │   ├── messaging_service.dart
│   │   └── shared_pref_service.dart  ← SharedPrefService.token key
│   ├── themes/
│   │   └── light_theme/
│   │       └── light_theme.dart
│   ├── utils/
│   │   ├── helper_functions.dart
│   │   ├── logout.dart
│   │   ├── show_dialogue_infos.dart
│   │   ├── show_dialogue_question.dart
│   │   ├── show_error_dialogue.dart   ← showDialogueError(context, errors)
│   │   ├── show_progress_dialogue.dart
│   │   ├── show_toast.dart            ← showToast(title, context, ...)
│   │   └── texts.dart
│   └── validator/
│       └── validator.dart             ← Validator builder class
├── components/                        ← global reusable widgets
│   └── form_field.dart                ← MyFormField(...)
├── exceptions/                        ← custom exceptions
│   ├── network_connectivity_exception.dart
│   ├── unauthenticated_exception.dart
│   ├── unauthorized_exception.dart
│   └── validation_exception.dart      ← ValidatorException with errors map
├── models/                            ← all data models
├── repository/
│   ├── repository.dart                ← main Repository class wrapping all providers
│   └── data_providers/
│       └── api/
│           └── api_client.dart        ← ApiClient(baseUrl, token, apiAppsVersion)
└── features/                          ← one folder per feature
├── [feature_name]/
│   ├── cubit/
│   │   ├── [name]_cubit.dart
│   │   └── [name]_state.dart
│   └── ui/
│       ├── [name]_page.dart
│       └── components/        ← widgets used only by this screen

---

## Folder Rules

### `components/` (global)
- Contains shared widgets reused across multiple features
- **Always check here first** before creating a new widget
- Existing components to reuse: `MyFormField`, and others
- If building something reusable across screens → place it here

### `exceptions/`
- All API/network errors have dedicated exception classes
- Always catch these in cubits (see cubit pattern below)

### `models/`
- One file per model
- Named in PascalCase: `Client`, `Booking`, `Manager`

### `repository/`
- `repository.dart` is the single access point for all data operations
- `data_providers/api/api_client.dart` handles all HTTP calls
- To add a new data source (local DB, cache), add a new folder under `data_providers/`

---

## Patterns to Follow

### Validator (for TextFormField)
```dart
// Chain-based builder — always use .make() at the end
validator: Validator().required().min(2).make()
validator: Validator().email().make()
validator: Validator().required().integer().min(10).make()
validator: Validator().required().min(8).contains([Components.letters, Components.numbers]).make()
validator: Validator().confirmPass(passwordController).make()
```

### MyFormField (global component)
```dart
MyFormField(
  label: "Label *",
  hint: "hint text",
  labelColor: Colors.black,
  borderColor: Colors.black,
  hintColor: Colors.black54,
  activeBorderColor: Colors.black,
  controller: myController,
  validator: Validator().required().make(),
  inputType: TextInputType.text, // optional
)
```

### AppColors
```dart
// Always use AppColors instead of hardcoded colors
color: AppColors.primaryColor
```

### AppStrings
```dart
// Always use AppStrings for user-facing messages
AppStrings.error
AppStrings.success
AppStrings.checkConnectivity
AppStrings.authorizationError
```

### show utilities
```dart
// Toast notification
showToast(
  AppStrings.success,
  context,
  second: 2,
  type: ToastificationType.success,
  whenComplete: () { /* optional callback */ },
);

// Error dialog (for validation errors map)
showDialogueError(context, state.errors!);
```

---

## State Pattern (Cubit)

### State file
```dart
part of '[name]_cubit.dart';

class [Name]State {
  AppStatus? [action]Status;
  String? error;
  [Model]? [model];
  Map<String, dynamic>? errors; // for validation errors from API

  [Name]State({
    this.[action]Status,
    this.error,
    this.[model],
    this.errors,
  });

  [Name]State copyWith({
    AppStatus? [action]Status,
    String? error,
    [Model]? [model],
    Map<String, dynamic>? errors,
  }) {
    return [Name]State(
      [action]Status: [action]Status ?? this.[action]Status,
      error: error,               // ← do NOT use ?? here (allows clearing error)
      [model]: [model] ?? this.[model],
      errors: errors,             // ← do NOT use ?? here
    );
  }
}
```

### Cubit file
```dart
import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../exceptions/validation_exception.dart';
import '../../../../repository/repository.dart';

part '[name]_state.dart';

class [Name]Cubit extends Cubit<[Name]State> {
  [Name]Cubit() : super([Name]State());

  void [action]([Model] model) async {
    try {
      emit(state.copyWith([action]Status: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      [Model] result = await repository.[action](model);
      emit(state.copyWith([action]Status: AppStatus.success, [model]: result));
    } on NetworkConnectivityException {
      emit(state.copyWith([action]Status: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith([action]Status: AppStatus.error, error: AppStrings.authorizationError));
    } on ValidatorException catch (ex) {
      emit(state.copyWith([action]Status: AppStatus.error, errors: ex.errors));
    } catch (ex) {
      emit(state.copyWith([action]Status: AppStatus.error, error: AppStrings.error));
      rethrow;
    }
  }
}
```

---

## Page Pattern
```dart
class [Name]Page extends StatefulWidget {
  // Always expose a static page() factory for BlocProvider wrapping
  static Widget page() {
    return BlocProvider<[Name]Cubit>(
      create: (context) => [Name]Cubit(),
      child: [Name]Page(),
    );
  }

  @override
  State<[Name]Page> createState() => _[Name]PageState();
}

class _[Name]PageState extends State<[Name]Page> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("Title", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<[Name]Cubit, [Name]State>(
        listener: _listener,
        builder: (context, state) {
          // build UI
        },
      ),
    );
  }

  void _listener(BuildContext context, [Name]State state) {
    if (state.[action]Status == AppStatus.error) {
      if (state.errors != null) {
        showDialogueError(context, state.errors!);
      } else {
        showToast("", description: state.error ?? AppStrings.error, context, second: 3, type: ToastificationType.error);
      }
    } else if (state.[action]Status == AppStatus.success) {
      showToast(AppStrings.success, context, second: 2, type: ToastificationType.success, whenComplete: () {
        GoRouter.of(context).pop(state.[model]);
      });
    }
  }
}
```

---

## Route Registration

All routes are registered in `immobilier/lib/routes.dart` using `go_router`.
When adding a new page, always register it there using the static `.page()` factory:
```dart
GoRoute(
  path: '/[feature-path]',
  builder: (context, state) => [Name]Page.page(),
),
```

---

## Adding a New Feature — Checklist

Before creating any files, **ask the developer to confirm the feature folder path**, because the project may be split into modules with a different structure.

Then follow this order:
1. ✅ Confirm feature folder path with developer
2. ✅ Create model in `lib/models/[name].dart`
3. ✅ Add API call in `lib/repository/data_providers/api/api_client.dart`
4. ✅ Expose method in `lib/repository/repository.dart`
5. ✅ Create feature folder: `lib/features/[feature]/[screen]/`
6. ✅ Create cubit + state in `cubit/`
7. ✅ Create page + screen components in `ui/`
8. ✅ Register route in `routes.dart`
9. ✅ Check if any new widget should go in `components/` instead of screen-local

---

## Improvements to Apply
If you notice any of the following while working on the codebase, fix them:
- Hardcoded colors → replace with `AppColors`
- Hardcoded strings shown to users → replace with `AppStrings`
- Duplicated widgets across screens → move to `components/`
- Missing exception handling in cubits → add standard catch blocks
- `copyWith` using `??` on `error` or `errors` fields → remove `??` to allow clearing