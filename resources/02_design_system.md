# 02 Design System: Black, Yellow, and Crypto Accents

Built on Material Design 3. Dark theme is the primary and default theme. A light theme is optional and can ship as a stretch goal.

## 1. Color tokens

Define these in `lib/theme/lt_colors.dart` and map them into a `ColorScheme` in `lib/theme/lt_theme.dart`.

### Core (M3 roles)

| M3 role | Token | Hex | Use |
|---|---|---|---|
| `primary` | `lemon` | `#FFD60A` | Primary actions, FAB, active nav, key numbers |
| `onPrimary` | `ink` | `#0B0B0C` | Text/icons on lemon |
| `primaryContainer` | `lemonDeep` | `#3A3200` | Selected chips, active block background |
| `onPrimaryContainer` | `lemonSoft` | `#FFF3B0` | Text on lemonDeep |
| `secondary` | `ember` | `#FF9F0A` | Warnings, streak flame |
| `background` / `surface` | `ink` | `#0B0B0C` | Scaffold background |
| `surfaceContainerLowest` | `void` | `#050505` | Behind cards, timeline gutter |
| `surfaceContainer` | `graphite` | `#141416` | Cards, sheets |
| `surfaceContainerHigh` | `slate` | `#1C1C20` | Dialogs, elevated cards |
| `surfaceContainerHighest` | `steel` | `#26262B` | Input fields, chips |
| `onSurface` | `paper` | `#F5F5F0` | Primary text |
| `onSurfaceVariant` | `ash` | `#9A9AA3` | Secondary text, labels |
| `outline` | `wire` | `#2E2E35` | Dividers, card borders |
| `outlineVariant` | `wireSoft` | `#1F1F25` | Subtle grid lines |
| `error` | `coral` | `#FF453A` | Conflicts, destructive actions |

### Crypto accents (use sparingly, one per screen max for glow)

| Token | Hex | Use |
|---|---|---|
| `up` | `#30D158` | Positive delta, completed, "gain" |
| `down` | `#FF453A` | Negative delta, overrun, conflict |
| `neonGradientStart` | `#FFD60A` | Gradient start for hero cards |
| `neonGradientEnd` | `#FF9F0A` | Gradient end |
| `glow` | `#FFD60A` at 25% alpha | Soft shadow behind active elements |
| `tickerBg` | `#0F0F12` | Ticker strip background |
| `gridLine` | `#1A1A1F` | Chart background grid |

Gradient rule: `LinearGradient(begin: topLeft, end: bottomRight, colors: [neonGradientStart, neonGradientEnd])`. Only for hero numbers and the primary FAB. Never for body text.

### Category palette (for time blocks)

Six colors, all tested for contrast on `graphite`:

| Category | Hex |
|---|---|
| Deep work | `#FFD60A` (lemon) |
| Meetings | `#64D2FF` |
| Study | `#BF5AF2` |
| Health | `#30D158` |
| Admin | `#AC8E68` |
| Personal | `#FF9F0A` |

## 2. Typography

Use Material 3 `TextTheme`. Two families:

- **Display and body:** `Inter` (Google Fonts). Fallback: system sans.
- **Numerics and ticker:** `JetBrains Mono` (Google Fonts). Used for times, durations, prices-style counters, and the ticker.
- **App logo:** `Image.asset('resources/logo.png')` — rendered as an image asset everywhere, never as text-only. Fallback: `Text('LemonTrack')` if the asset fails to load.

| Role | Family | Size / weight | Use |
|---|---|---|---|
| `displayLarge` | Inter | 57 / 400 | Hero date only |
| `headlineMedium` | Inter | 28 / 600 | Screen titles |
| `titleLarge` | Inter | 22 / 600 | Card titles |
| `titleMedium` | Inter | 16 / 600 | Block titles |
| `bodyLarge` | Inter | 16 / 400 | Chat messages |
| `labelLarge` | Inter | 14 / 600 | Buttons |
| `labelSmall` | Inter | 11 / 500, letterSpacing 0.8, UPPERCASE | Section labels, crypto-style tags |
| `numericLarge` (custom) | JetBrains Mono | 40 / 700 | Big totals |
| `numericMedium` (custom) | JetBrains Mono | 20 / 600 | Times, durations |
| `ticker` (custom) | JetBrains Mono | 12 / 500 | Ticker strip |

Rule: times and durations always use a numeric style so columns align.

## 3. Shape, elevation, motion

- **Corner radius:** cards 20, sheets 28, chips 12, blocks 12, FAB 20. Use `RoundedRectangleBorder`.
- **Borders:** cards get a 1px `wire` border. Active or selected items get a 1px `lemon` border.
- **Elevation:** M3 tonal elevation only. No drop shadows except the `glow` on active items (`BoxShadow` blur 24, alpha 0.25).
- **Motion:** M3 emphasized easing. 300ms for containers, 150ms for color changes. Block drag uses a spring.
- **Haptics:** `HapticFeedback.selectionClick()` on snap, `mediumImpact()` on confirm.

## 4. Crypto-style components (custom widgets)

Build these in `lib/widgets/crypto/`. Each has a screenshot-able preview in the widget gallery.

1. **`TickerStrip`**
   Horizontal scrolling strip at the top of Today. Items: `Planned 6h 30m`, `Tracked 3h 12m`, `Streak 9d`, `Focus 84%`. Each item shows a value and a small up/down delta arrow in `up` or `down`.

2. **`PriceCard` (`StatCard`)**
   Card with label (labelSmall UPPERCASE), big mono value, and delta chip. Gradient border for hero stats only.

3. **`CandleBars`**
   Daily summary chart. Each bar is a block-duration bar: green when tracked ≥ planned, red when short, lemon outline when planned but not started. Wick line shows the planned range. Used on Summary.

4. **`OrderBookList`** (adapted)
   Upcoming blocks listed as bid/ask-style rows: time on the left, title in the middle, duration right-aligned in mono. Next block row is highlighted with the lemon glow.

5. **`ProgressRing`**
   Circular focus progress with a dashed outer ring (like a market depth ring). Center shows remaining time in `numericLarge`.

6. **`GlowChip`**
   Chip for categories and AI status. Uses `primaryContainer` fill and a 1px lemon border when active.

7. **`GridBackdrop`**
   Subtle `gridLine` background painted with `CustomPainter` behind timelines. Spacing 24px. Keep opacity low so blocks stay readable.

8. **`LiveDot`**
   Pulsing lemon dot for "AI listening" and "timer running". 1.2s loop.

## 5. Material 3 component mapping

| Need | Component | Notes |
|---|---|---|
| Primary action | `FilledButton` | Lemon background, ink text |
| Secondary | `OutlinedButton` | `wire` border |
| Add block | `FloatingActionButton.extended` | Gradient background via `Container` wrapper |
| Navigation | `NavigationBar` (M3) | Lemon indicator pill |
| Chat input | `TextField` filled | `steel` fill, 28 radius |
| Bottom sheets | `showModalBottomSheet` | `slate` background |
| Pickers | `showTimePicker` / `showDatePicker` | Themed through `ColorScheme` |
| Tool result cards | `Card.filled` | Shows action diff with Undo |
| Snackbars | `SnackBar` with action | Used for "Undo" after delete |

## 6. Accessibility

- Text contrast: `paper` on `ink` and `ink` on `lemon` both exceed 7:1.
- Never convey conflict by color alone. Pair `coral` with an icon and label.
- Minimum touch target 48dp.
- Respect system font scale up to 1.3x.

## 7. Theme code contract

```dart
// lib/theme/lt_theme.dart  (contract, not final code)
ThemeData ltDarkTheme() {
  final scheme = ColorScheme.dark(
    primary: LTColors.lemon,
    onPrimary: LTColors.ink,
    primaryContainer: LTColors.lemonDeep,
    onPrimaryContainer: LTColors.lemonSoft,
    secondary: LTColors.ember,
    surface: LTColors.ink,
    onSurface: LTColors.paper,
    onSurfaceVariant: LTColors.ash,
    outline: LTColors.wire,
    outlineVariant: LTColors.wireSoft,
    error: LTColors.coral,
    surfaceContainerLowest: LTColors.void_,
    surfaceContainer: LTColors.graphite,
    surfaceContainerHigh: LTColors.slate,
    surfaceContainerHighest: LTColors.steel,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme, /* textTheme, etc. */);
}
```

Done means: no widget in `lib/screens` or `lib/widgets` (except `lib/widgets/crypto/`) uses a raw `Color(0x...)` literal. Lint rule or grep check in `11`.
