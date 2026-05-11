# CLAUDE.md — Bricklack Mobile

## ¿Qué es este proyecto?

App mobile de Bricklack — plataforma para fans de LEGO que perdieron piezas de sus sets.
Comparte la misma base de datos Firestore y Cloud Functions que la web (bricklack.com).
El usuario puede buscar sets, trackear piezas encontradas, identificar piezas por foto con IA, y explorar MOCs de la comunidad.

**Repos relacionados:**
- Web: `manuelestrada01/bricklack` (React + Vite + Tailwind)
- Tokens: `manuelestrada01/bricklack-tokens` (Style Dictionary — fuente de verdad de diseño)
- Mobile: este repo

---

## Stack

- **Framework**: Flutter 3.29.2
- **Auth**: Firebase Auth — Google Sign-In únicamente
- **Base de datos**: Cloud Firestore (misma que la web — NO cambiar estructura)
- **Storage**: Firebase Storage
- **Navegación**: `go_router`
- **State management**: Riverpod (preferido) o Provider — NO usar setState fuera de widgets simples
- **Imágenes**: `cached_network_image`
- **UI**: diseño propio — NO usar component libraries (Material widgets base OK, pero siempre sobreescritos con el design system de Bricklack)
- **Animaciones**: Flutter nativo (`AnimationController`, `TweenAnimationBuilder`) — NO Lottie ni librerías externas salvo necesidad justificada
- **API externa**: Rebrickable API (mismos endpoints que la web)
- **IA**: Cloud Function proxy ya existente en el backend — el cliente nunca llama a Anthropic directamente

---

## Setup inicial (hacer una vez)

```bash
# 1. Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# 2. Conectar al proyecto Firebase existente (mismo que la web)
flutterfire configure --project=TU_FIREBASE_PROJECT_ID

# Esto genera: lib/firebase_options.dart
# Después descomentar las líneas de Firebase en lib/main.dart
```

---

## Estructura del proyecto

```
lib/
  core/
    theme/
      app_tokens.dart     ← AUTO-GENERADO desde bricklack-tokens, no editar a mano
      app_theme.dart      ← ThemeData con colores y tipografía Bricklack
    services/
      firebase_service.dart
      rebrickable_service.dart
  features/
    auth/                 ← Google Sign-In
    home/                 ← Pantalla principal + búsqueda
    dashboard/            ← Colección de proyectos del usuario
    project/              ← Vista de proyecto + marcar piezas
    search/               ← Búsqueda de sets y piezas
    identify/             ← Identificar pieza por foto (IA)
    community/            ← MOCs públicos
```

---

## Design System

Tokens en `lib/core/theme/app_tokens.dart` — generados desde `manuelestrada01/bricklack-tokens`.
**No editar `app_tokens.dart` a mano.** Para cambiar valores, editar los JSON en bricklack-tokens y regenerar.

### Colores clave
```dart
AppColors.navy_base      // #0A1628 — texto principal, headings
AppColors.lego_yellow    // #FBBC05 — acento, CTAs, progreso, highlights
AppColors.background     // #F8F7F4 — fondo de pantallas
AppColors.surface        // #FFFFFF — fondo de cards y paneles
AppColors.cream_base     // #F5F0E8 — fondo de imágenes dentro de cards
AppColors.status_success // #22C55E
AppColors.status_warning // #F59E0B
AppColors.status_error   // #EF4444
```

### Radios
```dart
AppRadius.brick  // 6px — radio estándar de cards
AppRadius.md     // 8px
AppRadius.lg     // 12px
AppRadius.xl     // 16px
```

### Tipografía
- **Display + body**: `Outfit` (agregar a `pubspec.yaml` desde Google Fonts)
- **Números de piezas, IDs, cantidades**: `JetBrains Mono`

### Estética general
- Fondo de pantalla: `AppColors.background` (`#F8F7F4`)
- Cards: `AppColors.surface` con borde `AppColors.navy_base` al 8% de opacidad
- Imágenes dentro de cards: fondo `AppColors.cream_base`
- Texto principal: `AppColors.navy_base`
- Texto secundario: `AppColors.navy_base` al 30–40% de opacidad
- Acento interactivo: `AppColors.lego_yellow` — botones primarios, barras de progreso, estados activos

---

## Estructura de Datos Firestore

**CRÍTICO: No cambiar esta estructura — la web Flutter y la web React comparten los mismos documentos.**

```
users/{userId}
  - displayName: string
  - email: string
  - photoURL: string
  - createdAt: timestamp
  - scanCount: number          // escaneos IA usados en el mes actual
  - scanResetDate: timestamp   // fecha del último reset mensual
  - mocCount: number           // MOCs publicados (máx 5)

users/{userId}/projects/{projectId}
  - name: string
  - setId: string | null
  - setName: string | null
  - setImageUrl: string | null
  - status: 'in_progress' | 'completed' | 'paused'
  - createdAt: timestamp
  - updatedAt: timestamp
  - totalPieces: number
  - foundPieces: number

users/{userId}/projects/{projectId}/pieces/{pieceId}
  - partNum: string
  - name: string
  - color: string
  - colorCode: string
  - imageUrl: string
  - quantityRequired: number
  - quantityFound: number
  - isComplete: boolean

community_projects/{projectId}
  - authorId: string
  - authorName: string
  - authorPhotoURL: string
  - name: string
  - description: string
  - imageUrl: string
  - totalPieces: number
  - cloneCount: number
  - status: 'active' | 'flagged' | 'removed'
  - createdAt: timestamp
  - updatedAt: timestamp

community_projects/{projectId}/pieces/{pieceId}
  - partNum: string
  - name: string
  - color: string
  - colorCode: string
  - imageUrl: string
  - quantityRequired: number
```

---

## Integración Rebrickable API

Base URL: `https://rebrickable.com/api/v3/lego/`
Headers: `Authorization: key {API_KEY}`

```
GET /sets/{set_num}/          → info del set
GET /sets/{set_num}/parts/    → inventario de piezas
GET /parts/{part_num}/        → info de una pieza
GET /sets/?search=...         → búsqueda de sets
GET /parts/?search=...        → búsqueda de piezas
```

La API key va en variables de entorno — nunca hardcodeada.

---

## Reglas de Negocio

### Límite de escaneos IA
- Requiere login obligatorio
- 3 escaneos gratuitos por mes por usuario
- Verificar `scanCount` y `scanResetDate` en Firestore antes de llamar a la Cloud Function
- La verificación definitiva está en la Cloud Function — el cliente también verifica para UX

### Caché de sets
- Al agregar un set, guardar el inventario en `sets/{setId}/pieces` en Firestore
- Los siguientes usuarios usan el caché, no llaman a Rebrickable de nuevo

### MOCs de comunidad
- Publicar requiere auth obligatorio
- Máximo 5 MOCs por usuario (`mocCount`)
- Imagen del MOC obligatoria — sube a Firebase Storage bajo `mocs/{projectId}/cover`
- Al clonar un MOC: crear copia en `users/{userId}/projects/` con `clonedFrom: projectId` + incrementar `cloneCount` con transaction

---

## Rutas (go_router)

```
/                   → Home + búsqueda
/search             → Resultados de búsqueda
/set/:setId         → Detalle de un set
/piece/:partNum     → Detalle de una pieza
/dashboard          → Colección de proyectos (requiere auth)
/project/:projectId → Vista de proyecto (requiere auth)
/identify           → Identificar pieza por foto (requiere auth)
/community          → MOCs públicos
/community/:id      → Detalle de un MOC
/moc/new            → Crear MOC (requiere auth)
```

---

## Orden de Desarrollo

1. `flutterfire configure` → conectar Firebase
2. Auth con Google Sign-In + redirect guard en go_router
3. Home screen + búsqueda de sets
4. Dashboard — lista de proyectos desde Firestore
5. Vista de proyecto — lista de piezas + marcar como encontrada
6. Caché de sets en Firestore
7. Identificación de pieza por foto (cámara nativa + Cloud Function)
8. Comunidad MOCs — explorar, clonar, publicar
9. Pulido visual, animaciones, responsive, deploy

---

## Notas

- Ante la duda entre velocidad y calidad, priorizar calidad — este proyecto va al portfolio
- Cada pantalla debe tener identidad visual propia siguiendo el design system
- Las Cloud Functions son agnósticas al cliente — no enviar headers ni campos específicos de mobile que rompan la web
- `app_tokens.dart` se regenera desde bricklack-tokens cuando hay cambios de diseño — nunca editar a mano
