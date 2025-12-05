# Architecture Diagrams

These diagrams can be rendered using any Mermaid-compatible viewer (GitHub, VS Code extension, Mermaid Live Editor).

## Docker Desktop WSL2 Storage Architecture

```mermaid
flowchart TB
    subgraph Windows["Windows Host"]
        DD[Docker Desktop GUI]
        WI[WSL2 Integration]
        
        subgraph VHDX["VHDX Storage Layer"]
            VF[docker_data.vhdx]
            
            subgraph EXT4["ext4 Filesystem"]
                IMG[Images]
                VOL[Volumes]
                CACHE[Build Cache]
                CONT[Containers]
            end
        end
    end
    
    DD --> WI
    WI --> VF
    VF --> EXT4
    
    style VF fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style VHDX fill:#ffe066,stroke:#fab005
    style Windows fill:#e7f5ff,stroke:#1c7ed6
```

## The Problem: Auto-Expand, Never Shrink

```mermaid
flowchart LR
    subgraph Before["Before Development"]
        B1[VHDX: 1 GB]
    end
    
    subgraph During["During AI Development"]
        D1[Pull Base Images +5GB]
        D2[Build ML Images +20GB]
        D3[Download Models +50GB]
        D4[Create Volumes +30GB]
    end
    
    subgraph After["After docker prune"]
        A1[VHDX: Still 106 GB!]
        A2[Internal: 10 GB used]
    end
    
    B1 --> D1 --> D2 --> D3 --> D4 --> A1
    A1 -.->|"Never shrinks"| A2
    
    style A1 fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style A2 fill:#51cf66,stroke:#2f9e44,color:#fff
```

## The Solution: Export-Unregister-Import Workflow

```mermaid
flowchart TD
    START([Start: 150 GB VHDX]) --> SHUTDOWN[wsl --shutdown]
    
    SHUTDOWN --> EXPORT[Export docker-desktop to .tar]
    EXPORT --> UNREG[Unregister docker-desktop]
    UNREG --> DELETE[Delete old VHDX file]
    DELETE --> RESTART[Restart Docker Desktop]
    RESTART --> RECREATE[Docker recreates fresh VHDX]
    RECREATE --> SPARSE[Enable sparse mode]
    SPARSE --> TRIM[Run Windows TRIM]
    TRIM --> FINISH([Finish: 3 GB VHDX])
    
    style START fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style FINISH fill:#51cf66,stroke:#2f9e44,color:#fff
```

## Sparse Mode Behavior

```mermaid
stateDiagram-v2
    [*] --> NonSparse: Default VHDX
    
    NonSparse --> Growing: Write Data
    Growing --> Growing: More Writes
    Growing --> NonSparse: Delete Data (No Shrink!)
    
    NonSparse --> Sparse: Enable Sparse Mode
    
    Sparse --> Growing2: Write Data
    Growing2 --> Sparse: Delete Data
    Sparse --> Shrinking: Windows TRIM
    Shrinking --> Sparse: Space Reclaimed
    
    note right of NonSparse
        File size only grows
        Never decreases
    end note
    
    note right of Sparse
        Deleted blocks marked
        Can be reclaimed
    end note
```

## Script Execution Flow

```mermaid
sequenceDiagram
    participant User
    participant Script
    participant WSL
    participant Docker
    participant NTFS
    
    User->>Script: Run shrink-docker-wsl.ps1
    
    Script->>WSL: wsl --shutdown
    WSL-->>Script: All instances stopped
    
    Script->>WSL: wsl --export docker-desktop
    WSL-->>Script: Export complete (docker.tar)
    
    Script->>WSL: wsl --unregister docker-desktop
    WSL-->>Script: Distro unregistered
    
    Script->>NTFS: Delete docker_data.vhdx
    NTFS-->>Script: File deleted (space freed!)
    
    Script->>Docker: Start Docker Desktop
    Docker->>WSL: Create new docker-desktop
    WSL->>NTFS: Create new small VHDX
    Docker-->>Script: Ready
    
    Script->>WSL: wsl --manage --set-sparse true
    WSL-->>Script: Sparse mode enabled
    
    Script->>NTFS: defrag /L (TRIM)
    NTFS-->>Script: TRIM complete
    
    Script-->>User: Done! 150GB -> 3GB
```

## Decision Tree: When to Shrink

```mermaid
flowchart TD
    Q1{VHDX > 50 GB?}
    Q1 -->|No| OK1[Monitor - OK for now]
    Q1 -->|Yes| Q2{Disk space critical?}
    
    Q2 -->|Yes| SHRINK[Run Shrink Script NOW]
    Q2 -->|No| Q3{Sparse enabled?}
    
    Q3 -->|Yes| TRIM[Try TRIM first: defrag C: /L]
    Q3 -->|No| ENABLE[Enable sparse mode]
    
    TRIM --> Q4{Size reduced?}
    Q4 -->|Yes| OK2[Done!]
    Q4 -->|No| SHRINK
    
    ENABLE --> TRIM
    
    SHRINK --> DONE[VHDX shrunk to minimal size]
    
    style SHRINK fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style DONE fill:#51cf66,stroke:#2f9e44,color:#fff
    style OK1 fill:#51cf66,stroke:#2f9e44,color:#fff
    style OK2 fill:#51cf66,stroke:#2f9e44,color:#fff
```

---

## How to Render These Diagrams

### GitHub

GitHub automatically renders Mermaid diagrams in Markdown files.

### VS Code

Install the "Markdown Preview Mermaid Support" extension.

### Mermaid Live Editor

Visit [mermaid.live](https://mermaid.live) and paste the diagram code.

### Export to PNG

Use the Mermaid CLI:

```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i docs/mermaid-diagram.md -o assets/diagram.png
```
