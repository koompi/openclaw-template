---
name: sync
description: Universal context primer. When User says "@botname sync" or "sync", immediately load all memory, check infrastructure, and report active state. Use when switching topics or starting a new session mid-day.
---

# Sync — Full Context Primer

**Trigger:** User says "sync" or "@botname sync" in any topic.

## Steps (execute immediately, in order)

1. **Memory recall**
   - Read `MEMORY.md`
   - Read `memory/corrections.md`
   - Read `memory/YYYY-MM-DD.md` for today and yesterday
   - Run `memory_search("active projects tasks recent context")`

2. **Infrastructure check**
   - Read `SYSTEMS.md`
   - Run `pm2 list`
   - Run `pm2 jlist` if there are running processes (get details)
   - Check `zeroclaw cron list --include-disabled` for active crons

3. **Project state**
   - Check if `planning/progress.md` exists and has unfinished tasks
   - Check `planning/task_plan.md` for any active project plans
   - Scan `memory/projects/` for any in-progress projects

4. **Report format**
   Send a concise status report:
   ```
   🔄 SYNC COMPLETE
   
   📋 Active Projects: [list with status]
   ⚙️ PM2 Processes: [list]
   ⏰ Active Crons: [list]
   📝 Today's Activity: [brief summary from daily memory]
   ⚠️ Open Items: [anything needing User attention]
   
   Ready. What are we working on?
   ```

## Rules
- Do NOT skip any step
- Do NOT ask questions — just load and report
- Keep the report under 1500 characters
- If this is a group topic, be aware of cross-topic context from HEARTBEAT.md scans
