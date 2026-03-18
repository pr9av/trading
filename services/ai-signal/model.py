"""
AI Signal Service — LSTM Model
================================
PyTorch LSTM model for short-term price movement prediction.
Input: sliding window of normalized OHLCV features
Output: probability distribution over [BUY, HOLD, SELL]
"""

import logging
import os
from pathlib import Path

import torch
import torch.nn as nn

logger = logging.getLogger("ai-signal.model")

SEQUENCE_LENGTH = 60    # 60 ticks look-back window
INPUT_FEATURES  = 6     # [ltp, open, high, low, volume, spread]
HIDDEN_SIZE     = 128
NUM_LAYERS      = 2
NUM_CLASSES     = 3     # BUY, HOLD, SELL
DROPOUT         = 0.25


class LSTMPricePredictor(nn.Module):
    """
    Stacked LSTM + fully connected classifier for price direction prediction.
    Architecture: LSTM (2 layers) → Dropout → Linear → LogSoftmax
    """

    def __init__(
        self,
        input_size:  int = INPUT_FEATURES,
        hidden_size: int = HIDDEN_SIZE,
        num_layers:  int = NUM_LAYERS,
        num_classes: int = NUM_CLASSES,
        dropout:     float = DROPOUT,
    ) -> None:
        super().__init__()
        self.lstm = nn.LSTM(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            batch_first=True,
            dropout=dropout,
        )
        self.layer_norm = nn.LayerNorm(hidden_size)
        self.dropout    = nn.Dropout(dropout)
        self.fc         = nn.Linear(hidden_size, num_classes)
        self.log_softmax = nn.LogSoftmax(dim=1)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: (batch, seq_len, input_size)
        lstm_out, _ = self.lstm(x)
        last_hidden  = lstm_out[:, -1, :]           # Take last time step
        normalized   = self.layer_norm(last_hidden)
        dropped      = self.dropout(normalized)
        logits       = self.fc(dropped)
        return self.log_softmax(logits)


# ── Model Loader ──────────────────────────────────────────────────────────────

class LSTMSignalModel:
    """Wraps LSTMPricePredictor with load/save utilities."""

    LABEL_MAP = {0: "BUY", 1: "HOLD", 2: "SELL"}

    def __init__(self) -> None:
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model  = LSTMPricePredictor().to(self.device)
        self.model.eval()

        model_path = Path(os.getenv("MODEL_PATH", "/app/models/lstm_model.pt"))
        if model_path.exists():
            self.model.load_state_dict(torch.load(model_path, map_location=self.device))
            logger.info("LSTM model loaded from %s (device=%s)", model_path, self.device)
        else:
            logger.warning("No pretrained model found at %s — using random weights (dev mode)", model_path)

    def predict(self, sequence: list[list[float]]) -> tuple[str, float]:
        """
        Given a sequence of feature vectors, return (signal_label, confidence).
        sequence: list of SEQUENCE_LENGTH rows, each with INPUT_FEATURES floats.
        """
        x = torch.tensor([sequence], dtype=torch.float32).to(self.device)  # (1, seq, feat)
        with torch.no_grad():
            log_probs = self.model(x)
            probs     = torch.exp(log_probs)[0]
            class_idx = probs.argmax().item()
            confidence = probs[class_idx].item()

        signal = self.LABEL_MAP[class_idx]
        return signal, round(confidence, 4)
