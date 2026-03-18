"""
AI Signal Service — Model Trainer
===================================
Trains LSTM model on historical market data and synthetic data.
"""

import logging
import os
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset

from model import LSTMPricePredictor, SEQUENCE_LENGTH, INPUT_FEATURES, NUM_CLASSES

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
)
logger = logging.getLogger("ai-signal.trainer")

EPOCHS = 50
BATCH_SIZE = 32
LEARNING_RATE = 0.001
VALIDATION_SPLIT = 0.2


class SequenceDataGenerator:
    """Generates training sequences from tick data."""

    @staticmethod
    def generate_sequences(data: np.ndarray, sequence_length: int = SEQUENCE_LENGTH) -> tuple:
        """
        Create sequences from data.
        data shape: (num_samples, num_features)
        Returns: (X, y) where X is sequences and y is labels
        """
        X, y = [], []
        for i in range(len(data) - sequence_length):
            X.append(data[i:i + sequence_length])
            # Label: 0=BUY (up), 1=HOLD (stable), 2=SELL (down)
            last_price = data[i + sequence_length - 1, 0]
            next_price = data[i + sequence_length, 0]
            price_change = (next_price - last_price) / last_price
            
            if price_change > 0.01:  # >1% move
                label = 0  # BUY
            elif price_change < -0.01:  # <-1% move
                label = 2  # SELL
            else:
                label = 1  # HOLD
            
            y.append(label)
        
        return np.array(X), np.array(y)


class LSTMTrainer:
    """Handles training and evaluation of LSTM model."""

    def __init__(self, device: str = None) -> None:
        if device is None:
            self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        else:
            self.device = torch.device(device)
        
        self.model = LSTMPricePredictor().to(self.device)
        self.criterion = nn.CrossEntropyLoss()
        self.optimizer = optim.Adam(self.model.parameters(), lr=LEARNING_RATE)
        logger.info(f"Trainer initialized on device: {self.device}")

    def train(self, train_loader: DataLoader, val_loader: DataLoader = None, epochs: int = EPOCHS) -> dict:
        """Train the LSTM model."""
        history = {"train_loss": [], "val_loss": [], "val_acc": []}
        
        for epoch in range(epochs):
            # Training phase
            self.model.train()
            train_loss = 0.0
            for X_batch, y_batch in train_loader:
                X_batch = X_batch.to(self.device)
                y_batch = y_batch.to(self.device)
                
                self.optimizer.zero_grad()
                logits = self.model(X_batch)
                loss = self.criterion(logits, y_batch)
                loss.backward()
                self.optimizer.step()
                
                train_loss += loss.item()
            
            avg_train_loss = train_loss / len(train_loader)
            history["train_loss"].append(avg_train_loss)
            
            # Validation phase
            if val_loader:
                val_loss, val_acc = self.evaluate(val_loader)
                history["val_loss"].append(val_loss)
                history["val_acc"].append(val_acc)
                
                if (epoch + 1) % 10 == 0:
                    logger.info(
                        f"Epoch {epoch + 1}/{epochs} | "
                        f"Train Loss: {avg_train_loss:.4f} | "
                        f"Val Loss: {val_loss:.4f} | "
                        f"Val Acc: {val_acc:.4f}"
                    )
            else:
                if (epoch + 1) % 10 == 0:
                    logger.info(f"Epoch {epoch + 1}/{epochs} | Train Loss: {avg_train_loss:.4f}")
        
        return history

    def evaluate(self, val_loader: DataLoader) -> tuple:
        """Evaluate model on validation set."""
        self.model.eval()
        val_loss = 0.0
        correct = 0
        total = 0
        
        with torch.no_grad():
            for X_batch, y_batch in val_loader:
                X_batch = X_batch.to(self.device)
                y_batch = y_batch.to(self.device)
                
                logits = self.model(X_batch)
                loss = self.criterion(logits, y_batch)
                val_loss += loss.item()
                
                _, predicted = torch.max(logits.data, 1)
                correct += (predicted == y_batch).sum().item()
                total += y_batch.size(0)
        
        avg_val_loss = val_loss / len(val_loader)
        accuracy = correct / total
        return avg_val_loss, accuracy

    def save_model(self, path: str) -> None:
        """Save model weights."""
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        torch.save(self.model.state_dict(), path)
        logger.info(f"Model saved to {path}")


def generate_synthetic_training_data(num_samples: int = 10000) -> tuple:
    """Generate synthetic market data for training."""
    np.random.seed(42)
    
    # Simulate OHLCV data
    data = []
    price = 100.0
    
    for _ in range(num_samples):
        drift = 0.0001
        volatility = 0.02
        change = np.random.normal(drift, volatility)
        price *= (1 + change)
        
        ltp = price
        open_p = price * (1 - np.random.uniform(0, 0.005))
        high = price * (1 + np.random.uniform(0, 0.008))
        low = price * (1 - np.random.uniform(0, 0.008))
        volume = np.random.uniform(0, 1000000) / 1_000_000
        spread = np.random.uniform(0, 0.001)
        
        data.append([ltp, open_p, high, low, volume, spread])
    
    return np.array(data)


if __name__ == "__main__":
    logger.info("Starting LSTM model training...")
    
    # Generate synthetic data
    data = generate_synthetic_training_data(10000)
    logger.info(f"Generated synthetic data with shape: {data.shape}")
    
    # Create sequences
    X, y = SequenceDataGenerator.generate_sequences(data)
    logger.info(f"Sequences generated: X shape={X.shape}, y shape={y.shape}")
    
    # Convert to PyTorch tensors
    X_tensor = torch.FloatTensor(X)
    y_tensor = torch.LongTensor(y)
    
    # Split into train/val
    split_idx = int(len(X_tensor) * (1 - VALIDATION_SPLIT))
    X_train, X_val = X_tensor[:split_idx], X_tensor[split_idx:]
    y_train, y_val = y_tensor[:split_idx], y_tensor[split_idx:]
    
    # Create DataLoaders
    train_dataset = TensorDataset(X_train, y_train)
    val_dataset = TensorDataset(X_val, y_val)
    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False)
    
    # Train model
    trainer = LSTMTrainer()
    history = trainer.train(train_loader, val_loader, epochs=EPOCHS)
    
    # Save model
    model_path = os.getenv("MODEL_PATH", "/app/models/lstm_model.pt")
    trainer.save_model(model_path)
    logger.info("Training complete!")
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
            
        logger.info(f"Epoch {epoch+1}/{epochs} - Loss: {total_loss/len(loader):.4f}")

    torch.save(model.state_dict(), "models/lstm_model.pt")
    logger.info("Model saved to models/lstm_model.pt")

if __name__ == "__main__":
    import os
    if not os.path.exists("models"):
        os.makedirs("models")
    train_model(epochs=1) # Fast run for placeholder
