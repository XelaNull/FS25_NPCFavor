# NPC Favor – TODO / Roadmap

This TODO list reflects the **current state of the mod** and the **updated vision** for NPC Favor. Items are grouped by priority and maturity rather than strict versioning. Some items are aspirational and depend on FS25 engine limitations.

---

## ✅ Already Implemented / In Progress

* NPC system initialized and loading correctly
* NPCs visible in-game
* Basic NPC identity persistence (ID-based)
* Debug logging framework
* Early structure for favor tracking
* Map icon concept identified (implementation pending)

---

## 🔜 Short-Term TODO (Foundation & Polish)

### NPC Presence & UX

* Add NPC map icons (toggleable)
* Improve NPC visibility consistency (spawn/despawn edge cases)
* Ensure NPCs do not feel intrusive or clutter the map
* Add basic NPC info tooltip (name / role)

### Favor System (Core)

* Define favor data structure (type, status, timestamps)
* Implement basic favor lifecycle:

  * Requested
  * Accepted
  * Completed
  * Failed / Expired
* Store favor history per NPC
* Simple rewards or acknowledgements for completed favors

### Persistence

* Save/load NPC state reliably across sessions
* Save favor progress and history
* Handle missing or removed NPCs gracefully

---

## 🧠 Medium-Term TODO (Depth & Believability)

### NPC Behavior

* Assign NPC roles (farmer, shop-related, resident, etc.)
* Soft daily routines (time-of-day driven)
* Basic location awareness (home / work / idle)
* Idle behaviors when not interacting with the player

### "Home" Concept

* Define home locations per NPC
* NPCs start/end their day at home
* Homes act as logical anchors, not interiors

### Favor Depth

* Contextual favor triggers (NPC stuck, missing delivery, etc.)
* Time-sensitive favors
* NPC reaction changes based on player reliability
* Track patterns, not just total favors

---

## 🚗 Vehicles & Movement (Experimental)

* Assign vehicles to NPCs (optional / role-based)
* NPCs travel to destinations using vehicles
* Allow non-perfect simulation (teleport, despawn outside view)
* Vehicle ownership persistence per NPC
* Basic parking logic near destinations

---

## 🎭 Personality & Variation

* Lightweight personality stats per NPC:

  * Patience
  * Generosity
  * Forgiveness
* Influence how NPCs request and react to favors
* Prevent all NPCs from feeling interchangeable

---

## 🌱 Long-Term / Aspirational

* NPCs requesting favors without player initiation
* NPCs refusing help based on past behavior
* NPC-to-NPC interactions (indirect, simulated)
* Reputation-based unlocks (discounts, access, trust)
* Seasonal or weather-influenced NPC behavior
* Hooks for other mods to register NPCs or favors

---

## 🧹 Technical & Maintenance

* Refactor code as systems stabilize
* Improve logging levels (debug / info / warn)
* Add config options for:

  * NPC count
  * Favor frequency
  * Debug visibility
* Performance checks with large NPC counts

---

## 🚫 Explicitly Out of Scope (For Now)

* Full NPC life simulation
* Interior NPC homes
* Heavy dialogue or branching narratives
* Relationship / dating mechanics

---

## Guiding Principle

> Every item on this list should support the core goal: making NPCs feel *noticed*, *persistent*, and *socially meaningful* without overwhelming the farming experience.

This list is expected to evolve as FS25 modding constraints and design ideas change.
