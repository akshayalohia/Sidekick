# UI Modernization Plan: Extending LibreChat Style Across Sidekick

## Overview
Extend the clean, modern LibreChat UI style across the entire Sidekick app, including settings, dialogs, menus, and all secondary views. Focus on consistency, animations, and polish.

## LibreChat Design Principles (Reference)

### Color System
- **Surface Colors:**
  - `surface-primary`: Main background (white/gray-900)
  - `surface-secondary`: Secondary backgrounds (gray-50/gray-800)
  - `surface-active`: Active/selected states (gray-100/gray-500)
  - `surface-active-alt`: Alternative active (gray-200/gray-700)
  - `surface-hover`: Hover states (gray-200/gray-600)
  - `surface-chat`: Chat input area (white/gray-700)
  - `surface-submit`: Submit buttons (green-700)
  - `surface-destructive`: Destructive actions (red-700/red-800)

- **Text Colors:**
  - `text-primary`: Main text (gray-800/gray-100)
  - `text-secondary`: Secondary text (gray-600/gray-300)
  - `text-tertiary`: Tertiary text (gray-500)

- **Border Colors:**
  - `border-light`: Subtle borders (gray-200/gray-700)
  - `border-medium`: Medium borders (gray-300/gray-600)
  - `border-heavy`: Strong borders (gray-400/gray-500)

### Typography
- Font: Inter (sans-serif), Roboto Mono (monospace)
- Consistent sizing: xs (0.75rem), sm (0.875rem), base (1rem), lg (1.125rem), xl (1.25rem)

### Spacing & Layout
- Consistent padding: 32px for major sections, 16px for components
- Border radius: 0.5rem (8px) default, pill buttons use `cornerRadius: 9999`
- Shadows: Subtle depth (2-8px radius, low opacity 0.1-0.3)

### Animations
- **Transitions:** 200-300ms cubic-bezier(0.25, 0.1, 0.25, 1)
- **Slide animations:** 300ms for panels/sidebars
- **Fade:** 0.5s ease-out
- **Toggle feedback:** Fast (0.05-0.1s) for instant response

### Button Styles
- **Pill-shaped buttons:** `cornerRadius: 9999`
- **Active states:** Bold color changes (solid blue/green), not opacity tints
- **Hover states:** Subtle background changes
- **Disabled states:** Reduced opacity (0.1-0.3), cursor-not-allowed

## Implementation Phases

### Phase 1: Foundation & Critical Fixes (HIGH PRIORITY)
**Goal:** Fix broken functionality and establish consistent design system

1. **Functions Button Master Switch** ⚠️ CRITICAL
   - Implement proper master toggle with state preservation
   - Fix architecture: decouple "should use functions" from "which functions"
   - File: `UseFunctionsButton.swift`

2. **Design System Components**
   - Create reusable button styles matching LibreChat
   - Create consistent form field styles
   - Create consistent card/panel styles
   - Files: New `Styles/` components

3. **Color System Consistency**
   - Audit all color usage across app
   - Ensure consistent use of semantic color names
   - Verify dark mode support

### Phase 2: Settings & Preferences (HIGH VISIBILITY)
**Goal:** Modernize all settings panels to match LibreChat's clean aesthetic

1. **SettingsView Container**
   - Modernize tab navigation
   - Add smooth transitions between tabs
   - Improve spacing and layout
   - Files: `SettingsView.swift`

2. **GeneralSettingsView**
   - Modernize form fields (replace `.roundedBorder` with custom style)
   - Add consistent spacing (32px padding)
   - Improve toggle switches styling
   - Add hover states
   - Files: `GeneralSettingsView.swift`

3. **InferenceSettingsView**
   - Modernize model selection UI
   - Improve server settings editor
   - Add animations for state changes
   - Files: `InferenceSettingsView.swift`, `ServerModelSettingsView.swift`

4. **RetrievalSettingsView**
   - Modernize retrieval configuration UI
   - Improve form layout
   - Files: `RetrievalSettingsView.swift`

5. **All Settings Sub-views**
   - Model management views
   - Inline Writing Assistant settings
   - System prompt editor
   - Files: All files in `Settings/` directory

### Phase 3: Dialogs & Modals (MEDIUM PRIORITY)
**Goal:** Modernize all dialogs, sheets, and popovers

1. **Expert Manager Dialog**
   - Modernize ExpertManagerView
   - Improve expert list styling
   - Add smooth animations
   - Files: `ExpertManagerView.swift`, `ExpertListView.swift`

2. **Setup Flow**
   - Modernize SetupView
   - Improve ModelSelectionView
   - Add smooth transitions
   - Files: `SetupView.swift`, `ModelSelectionView.swift`

3. **Memory Manager**
   - Modernize MemoriesManagerView
   - Improve memory list/cards
   - Files: `MemoriesManagerView.swift`

4. **All Sheet Presentations**
   - Consistent styling across all `.sheet()` presentations
   - Smooth animations
   - Proper padding and spacing

### Phase 4: Tools & Secondary Views (MEDIUM PRIORITY)
**Goal:** Modernize Dashboard, Diagrammer, Slide Studio, Detector, etc.

1. **Dashboard**
   - Modernize DashboardView
   - Improve card layouts
   - Add hover states and animations
   - Files: `DashboardView.swift`

2. **Diagrammer**
   - Modernize DiagrammerView and related views
   - Improve prompt input styling
   - Add smooth generation animations
   - Files: All files in `Tools/Diagrammer/`

3. **Slide Studio**
   - Modernize SlideStudioView and related views
   - Improve export options UI
   - Files: All files in `Tools/Slide Studio/`

4. **Detector**
   - Modernize DetectorView and related views
   - Improve result display
   - Files: All files in `Tools/Detector/`

5. **Tool Library**
   - Modernize ToolLibraryView
   - Improve tool cards
   - Files: `ToolLibraryView.swift`

### Phase 5: Menus & Navigation (LOW PRIORITY)
**Goal:** Polish all menus, popovers, and navigation elements

1. **Context Menus**
   - Consistent styling across all context menus
   - Smooth animations

2. **Popovers**
   - Ensure all popovers use consistent styling
   - Smooth show/hide animations
   - Proper positioning

3. **Navigation Elements**
   - Sidebar navigation polish
   - Breadcrumbs (if any)
   - Tab navigation

### Phase 6: Animations & Transitions (POLISH)
**Goal:** Add smooth animations throughout the app

1. **View Transitions**
   - Smooth transitions between views
   - Slide animations for panels
   - Fade animations for modals

2. **State Changes**
   - Animate toggle switches
   - Animate button state changes
   - Animate list item selection

3. **Loading States**
   - Consistent loading indicators
   - Smooth progress animations

## Technical Implementation Details

### SwiftUI Patterns to Use

1. **Button Styles**
```swift
struct LibreChatButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var variant: ButtonVariant = .default
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isActive ? Color("surface-submit") : Color("surface-chat")
            )
            .foregroundColor(isActive ? .white : Color("text-primary"))
            .cornerRadius(9999) // Pill shape
            .shadow(
                color: isActive ? Color.black.opacity(0.3) : Color.black.opacity(0.1),
                radius: isActive ? 8 : 2,
                x: 0,
                y: isActive ? 4 : 1
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
```

2. **Form Field Styles**
```swift
struct LibreChatTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color("surface-chat"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("border-medium"), lineWidth: 1)
            )
    }
}
```

3. **Animation Constants**
```swift
extension Animation {
    static let libreChatDefault = Animation.easeInOut(duration: 0.2)
    static let libreChatFast = Animation.easeInOut(duration: 0.05)
    static let libreChatSlide = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.3)
}
```

### Files to Create/Modify

**New Files:**
- `Sidekick/Views/Styles/LibreChatButtonStyle.swift`
- `Sidekick/Views/Styles/LibreChatTextFieldStyle.swift`
- `Sidekick/Views/Styles/LibreChatCardStyle.swift`
- `Sidekick/Views/Styles/LibreChatToggleStyle.swift`
- `Sidekick/Views/Styles/AnimationConstants.swift`

**Files to Modify:**
- All files in `Views/Settings/`
- All files in `Views/Expert/`
- All files in `Views/Tools/`
- All files in `Views/Setup/`
- All files in `Views/Misc/`
- Dialog and sheet presentations throughout

## Success Criteria

1. ✅ Consistent visual language across all views
2. ✅ Smooth animations (200-300ms transitions)
3. ✅ Proper hover and active states
4. ✅ Consistent spacing (32px major, 16px minor)
5. ✅ Pill-shaped buttons where appropriate
6. ✅ Proper shadows and depth
7. ✅ Dark mode support maintained
8. ✅ No broken functionality
9. ✅ Functions button works as master switch
10. ✅ Settings feel modern and polished

## Testing Checklist

- [ ] Test all settings panels
- [ ] Test all dialogs and modals
- [ ] Test all tools (Dashboard, Diagrammer, etc.)
- [ ] Test dark mode
- [ ] Test animations and transitions
- [ ] Test Functions button master switch
- [ ] Test form inputs and toggles
- [ ] Test navigation and menus

## Notes

- Reference LibreChat source at `/Documents/GitHub/SysLab/LibreChat`
- Use Context7 MCP for SwiftUI documentation when needed
- Maintain existing functionality - this is a visual refactor
- Use subagents for parallel work on different phases
- Focus on user experience and polish

