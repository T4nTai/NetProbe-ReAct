# Đề tài B2 — ReAct Agent định vị nguyên nhân sự cố mạng

Hệ thống ReAct Agent (xây dựng bằng **LangGraph** + **DeepSeek API**) định vị thiết bị gây lỗi (*root-cause node*) và loại lỗi (*failure type*) trên lab **Containerlab + FRRouting**, kèm bằng chứng kiểm chứng được và khuyến nghị xử lý an toàn.

- Proposal: [Group1_B2_Proposal.pdf](Group1_B2_Proposal.pdf)
- Kế hoạch triển khai & phân công: [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)

## Cấu trúc thư mục

```text
Big-Project/
├── lab/                # Topology Containerlab, cấu hình FRR chuẩn, scripts deploy/reset
│   ├── configs/
│   └── scripts/
├── datagen/            # Gieo 9 loại lỗi, sinh nhiễu N0/N1/N2, thu thập snapshot/log/probe
│   └── injectors/
├── tools/              # 10 tool chỉ đọc (ReplayBackend & LiveBackend) + schema evidence ID
├── baselines/          # Đối chứng nội bộ (H0, B0, B1, B1-log) & ngoài (E1, E2)
├── agent/              # ReAct Agent đề xuất (A2) với LangGraph + DeepSeek
├── eval/               # Evaluator thống nhất (Accuracy, NIKA, NetOpsBench, Safety) & plots
├── demo/               # CLI/UI demo chế độ Live & Replay
├── tests/              # Unit tests cho tools, verifier và evaluator
├── data/               # Dataset sinh ra (dev/, test/) - không commit lên git
├── results/            # Kết quả benchmark & biểu đồ - không commit lên git
└── docs/               # Tài liệu kỹ thuật (Data Contract, IP Plan, Design Baseline)
```

## Thiết lập môi trường (Linux)

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env
# Điền DEEPSEEK_API_KEY vào file .env
```

## Kiểm thử nhanh

```bash
pytest
```
