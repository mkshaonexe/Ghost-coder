# 🤖 AI Agent Skills Directory

This directory contains curated AI agent skills installed in this project for the **Google Antigravity SDK** and other agentic platforms.

An **Agent Skill** is a standardized way to give AI agents new capabilities, domain-specific knowledge, and expertise.

---

## 📋 Installed Skills

| Skill Folder Name | Repository Source | Skill Path (relative) | Description |
|---|---|---|---|
| **Swift SwiftUI Pro** | [twostraws/swiftui-agent-skill](https://github.com/twostraws/swiftui-agent-skill) | `skills/swiftui-agent-skill/swiftui-pro` | Comprehensive guide and design patterns for building modern SwiftUI applications. |
| **Swift Concurrency Pro** | [twostraws/Swift-Concurrency-Agent-Skill](https://github.com/twostraws/Swift-Concurrency-Agent-Skill) | `skills/Swift-Concurrency-Agent-Skill/swift-concurrency-pro` | Expert guidance, rules, and best practices for Swift Structured Concurrency. |
| **SwiftData Pro** | [twostraws/SwiftData-Agent-Skill](https://github.com/twostraws/SwiftData-Agent-Skill) | `skills/SwiftData-Agent-Skill/swiftdata-pro` | Best practices, configurations, and paradigms for SwiftData persistent storage. |
| **Swift Testing Pro** | [twostraws/Swift-Testing-Agent-Skill](https://github.com/twostraws/Swift-Testing-Agent-Skill) | `skills/Swift-Testing-Agent-Skill/swift-testing-pro` | High-quality unit and integration testing rules using the Swift Testing framework. |
| **Swift Agent Skills (Curated)** | [twostraws/swift-agent-skills](https://github.com/twostraws/swift-agent-skills) | `skills/swift-agent-skills` | Reference catalog of curated open-source Swift and Apple platform development agent skills. |
| **UI/UX Pro Max** | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | `skills/ui-ux-pro-max-skill/.claude/skills/` | Comprehensive UI/UX design intelligence skills including: `ui-ux-pro-max`, `design`, `banner-design`, `ui-styling`, `brand`, `slides`, `design-system`. |

---

## 🛠️ Google Antigravity SDK Setup

To load these skills in your Google Antigravity SDK agent, configure the `skills_paths` in `LocalAgentConfig`.

> [!IMPORTANT]
> The `skills_paths` configuration accepts a list of absolute or relative directory paths. You can pass:
> 1. A parent directory that contains skill folders (the agent will recursively discover all skills).
> 2. Specific skill folders directly.

### Example configuration in your Python script:

```python
import os
from google.antigravity import Agent, LocalAgentConfig

# Resolve the absolute path to this skills directory
current_dir = os.path.dirname(os.path.abspath(__file__))
skills_dir = os.path.join(current_dir, "skills")

config = LocalAgentConfig(
    skills_paths=[
        # Load all standard skills (swiftui, concurrency, data, testing)
        os.path.join(skills_dir, "swiftui-agent-skill"),
        os.path.join(skills_dir, "Swift-Concurrency-Agent-Skill"),
        os.path.join(skills_dir, "SwiftData-Agent-Skill"),
        os.path.join(skills_dir, "Swift-Testing-Agent-Skill"),
        
        # Load all ui-ux-pro-max sub-skills from the .claude/skills folder
        os.path.join(skills_dir, "ui-ux-pro-max-skill", ".claude", "skills"),
    ]
)

async with Agent(config) as agent:
    response = await agent.chat(
        "Based on the UI/UX Pro Max skill and SwiftUI Pro skill, "
        "what are the key principles I should follow when building the menu bar UI for a macOS application?"
    )
    print(await response.text())
```
