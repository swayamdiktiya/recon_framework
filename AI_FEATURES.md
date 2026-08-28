# AI Features

Recon Framework includes optional AI-powered analysis using Ollama (local LLM inference).

## Prerequisites

1. Install Ollama: https://ollama.com
2. Pull the security-tuned model:
   ```bash
   ollama pull gemma4-e4b-SecOps
   ```
3. Start Ollama (runs on `localhost:11434` by default)

## Usage

### Enable AI analysis
```bash
./recon.sh -ai example.com
```

### Use a different model
```bash
./recon.sh -ai -ai-model llama3.1 example.com
```

### Ask a question about results
```bash
./recon.sh -ai -ai-q "What XSS vulnerabilities were found?" example.com
```

### Custom Ollama URL
```bash
./recon.sh -ai -ai-url http://192.168.1.100:11434 example.com
```

## What AI Does

| Feature | Description |
|---------|-------------|
| **Adaptive Decisions** | AI analyzes early recon results and recommends which scan steps to run next |
| **Result Analysis** | Summarizes all findings, prioritizes vulnerabilities, identifies attack paths |
| **Report Generation** | Produces a professional pentest-style report from scan data |
| **Natural Language Q&A** | Ask questions about findings in plain English |

## AI Output

All AI outputs are saved to `<output_dir>/ai_analysis/`:

| File | Content |
|------|---------|
| `ai_analysis.md` | Full analysis with critical findings and next steps |
| `ai_decision.json` | Adaptive scan recommendations (which steps to run/skip) |
| `ai_report.md` | Complete pentest report with remediation |
| `.scan_summary.txt` | Collected scan data fed to AI |

## How It Works

1. After initial recon (step 3), AI decides which remaining steps are relevant
2. After all scans complete, AI analyzes all findings together
3. AI generates a prioritized report with evidence and remediation
4. You can ask follow-up questions about specific findings

## Model Recommendations

| Model | Size | Best For |
|-------|------|----------|
| `gemma4-e4b-SecOps` | 5.3GB | Security analysis (default) |
| `llama3.1` | 4.7GB | General purpose |
| `qwen3.6-27b-code-abliterated` | 16GB | Deep analysis (needs 32GB+ RAM) |

## Troubleshooting

**"AI: Ollama not reachable"**
- Ensure Ollama is running: `ollama serve`
- Check the URL: `curl http://localhost:11434/api/tags`

**"AI model not found"**
- Pull the model: `ollama pull gemma4-e4b-SecOps`
- List available models: `ollama list`

**AI is slow**
- First request is slow (model loading). Subsequent requests are faster.
- Increase timeout: the default is 120 seconds per query.
- Use a smaller model for faster results.
