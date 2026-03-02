Here is your Codex-ready SPRINT.md file. You can drop this directly into your repo root.

SPRINT.md
Project: CookBoard Platform: iPadOS + macOS (Universal SwiftUI App) Persistence: SwiftData + iCloud (CloudKit sync) Scope: Single-user (same iCloud account across devices)

🎯 Sprint Goal
Build a working MVP of a Freeform-style canvas combined with a Kanban board where:
	•	The same Card model powers both Canvas and Kanban
	•	Data syncs automatically across Mac + iPad via iCloud
	•	Canvas supports move/resize
	•	Kanban supports drag/drop between columns
	•	No multi-user collaboration (single iCloud user only)

🧱 Architecture Overview
Core Models (SwiftData)
Board
	•	id: UUID
	•	title: String
	•	updatedAt: Date
	•	viewportOffsetX: Double
	•	viewportOffsetY: Double
	•	viewportScale: Double
Card
	•	id: UUID
	•	board: Board (relationship)
	•	title: String
	•	content: String
	•	x: Double
	•	y: Double
	•	width: Double
	•	height: Double
	•	kanbanColumn: Column? (optional relationship)
	•	orderInColumn: Int
Column
	•	id: UUID
	•	board: Board (relationship)
	•	title: String
	•	order: Int
Key Rule: If kanbanColumn == nil → render on Canvas If kanbanColumn != nil → render inside that Kanban column

✅ Definition of Done (Global)
	•	App builds and runs on iPad simulator + macOS
	•	Create/edit/delete Boards, Cards, Columns
	•	Move/resize Cards on canvas
	•	Drag Cards between Kanban columns
	•	Changes persist after relaunch
	•	Create on Mac → appears on iPad (same iCloud)
	•	No duplicate cards when switching between canvas/kanban
	•	No crashes during normal usage

🚀 Sprint Tasks

1️⃣ Project Setup
1.1 Create Universal SwiftUI App
	•	iPadOS target
	•	macOS target (Mac Catalyst or native)
	•	Shared source folder
	•	Sidebar layout:
	◦	Board List
	◦	Board Detail View
ACCEPTANCE:
	•	App launches on both platforms
	•	Can select a board and navigate to detail view

2️⃣ SwiftData + CloudKit Sync
2.1 Implement SwiftData Models
	•	Add @Model classes for Board, Card, Column
	•	Implement relationships
	•	Add preview/sample data for debug builds
ACCEPTANCE:
	•	CRUD works locally
	•	Data persists after relaunch
2.2 Enable iCloud Sync
	•	Enable iCloud capability
	•	Configure CloudKit container
	•	Use SwiftData with CloudKit backing
	•	Add logging around model saves
ACCEPTANCE:
	•	Create board on Mac → appears on iPad
	•	Edit card on iPad → updates on Mac
	•	No manual refresh required
2.3 Sync Verification Checklist
Add /docs/DEV.md containing:
	•	How to test sync
	•	Required Apple ID setup
	•	Known simulator limitations

3️⃣ Canvas MVP
3.1 Infinite Canvas (Basic)
	•	Implement pan gesture
	•	Implement zoom gesture
	•	Persist viewport state per board
ACCEPTANCE:
	•	Pan/zoom smooth on both platforms
	•	Viewport state restores on reopen
3.2 Render Cards on Canvas
	•	Render cards where kanbanColumn == nil
	•	Position using x/y/width/height
	•	Drag to move
	•	Resize using corner handles
ACCEPTANCE:
	•	Move/resize persists
	•	Syncs across devices
3.3 Create Card on Canvas
	•	“+ Card” button in toolbar
	•	New card appears at viewport center
	•	Editable title + body
ACCEPTANCE:
	•	Card saves and syncs
	•	No layout glitches when zoomed

4️⃣ Kanban MVP
4.1 Kanban Layout
	•	Horizontal scroll columns
	•	Add/rename/delete column
	•	Reorder columns (basic implementation)
ACCEPTANCE:
	•	Columns persist and sync
4.2 Drag Cards Between Columns
	•	Only render cards where kanbanColumn != nil
	•	Drag to reorder inside column
	•	Drag to other columns
	•	Update orderInColumn
ACCEPTANCE:
	•	Drag works on touch + mouse
	•	Ordering persists after relaunch
4.3 Send Card To/From Kanban
	•	Add context menu:
	◦	“Send to Kanban”
	◦	“Send to Canvas”
ACCEPTANCE:
	•	Card moves without duplication
	•	Frame retained when returning to canvas

5️⃣ Optional: PencilKit Drawing Layer
5.1 Drawing Overlay
	•	Add PencilKit canvas behind cards
	•	Store drawing data on Board
	•	Toggle drawing mode
ACCEPTANCE:
	•	Draw on iPad with Apple Pencil
	•	Drawing persists and syncs

6️⃣ Stability + Tests
6.1 Unit Tests
Test:
	•	Create board/card/column
	•	Move card between columns
	•	Persistence correctness
	•	orderInColumn consistency
ACCEPTANCE:
	•	Tests run successfully
6.2 Debug Screen
Hidden debug view:
	•	Count of boards/cards/columns
	•	Last modified timestamps
	•	Button: “Create Sample Data”
ACCEPTANCE:
	•	Helps verify sync without Xcode console

⚠️ Guardrails
	•	Do NOT duplicate Card entities when moving between Canvas and Kanban
	•	Avoid heavy custom gesture conflicts
	•	Keep state single-source-of-truth in SwiftData
	•	Avoid premature optimization

🧠 Implementation Strategy for Codex
Codex should:
	•	Work one task at a time
	•	Create feature branches per task
	•	Open PRs with:
	◦	Summary
	◦	Screenshots (Mac + iPad)
	◦	Confirmation checklist
After each PR:
	•	Ensure it meets Acceptance Criteria
	•	Merge before starting next task

🏁 End of Sprint Outcome
At completion, CookBoard should:
	•	Sync seamlessly across Mac and iPad under one iCloud account
	•	Allow freeform spatial thinking
	•	Allow structured Kanban workflow
	•	Feel stable and native

If you want next, I can generate:
	•	A README.md optimized for Codex context-loading
	•	Or a stricter “Codex Execution Mode” version that reduces ambiguity even further
	•	Or a v2 Sprint for collaboration and real-time presence
