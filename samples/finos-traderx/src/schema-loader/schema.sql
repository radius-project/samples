DROP TABLE IF EXISTS Trades;
DROP TABLE IF EXISTS OrderBook;
DROP TABLE IF EXISTS AccountUsers;
DROP TABLE IF EXISTS Positions;
DROP TABLE IF EXISTS Accounts;
DROP SEQUENCE IF EXISTS ACCOUNTS_SEQ;

CREATE TABLE Accounts (ID INTEGER PRIMARY KEY, DisplayName VARCHAR(50));
CREATE TABLE AccountUsers (AccountID INTEGER NOT NULL, Username VARCHAR(15) NOT NULL, PRIMARY KEY (AccountID, Username));
ALTER TABLE AccountUsers ADD FOREIGN KEY (AccountID) REFERENCES Accounts(ID);

CREATE TABLE Positions (
  AccountID INTEGER,
  Security VARCHAR(15),
  Updated TIMESTAMP,
  Quantity INTEGER,
  AverageCostBasis DECIMAL(18,3),
  PRIMARY KEY (AccountID, Security)
);
ALTER TABLE Positions ADD FOREIGN KEY (AccountID) REFERENCES Accounts(ID);

CREATE TABLE Trades (
  ID VARCHAR(50) PRIMARY KEY,
  AccountID INTEGER,
  Created TIMESTAMP,
  Updated TIMESTAMP,
  Security VARCHAR(15),
  Side VARCHAR(10) CHECK (Side IN ('Buy', 'Sell')),
  Quantity INTEGER CHECK (Quantity > 0),
  Price DECIMAL(18,3),
  State VARCHAR(20) CHECK (State IN ('New', 'Processing', 'Settled', 'Cancelled'))
);
ALTER TABLE Trades ADD FOREIGN KEY (AccountID) REFERENCES Accounts(ID);

CREATE TABLE OrderBook (
  OrderId VARCHAR(32) PRIMARY KEY,
  AccountId INTEGER NOT NULL,
  Security VARCHAR(16) NOT NULL,
  Side VARCHAR(16) CHECK (Side IN ('Buy', 'Sell')),
  Quantity INTEGER NOT NULL CHECK (Quantity > 0),
  RemainingQuantity INTEGER NOT NULL CHECK (RemainingQuantity >= 0),
  LimitPrice DECIMAL(18,3) NOT NULL,
  Status VARCHAR(24) CHECK (Status IN ('NEW', 'PARTIALLY_FILLED', 'FILLED', 'CANCELED', 'REJECTED')),
  CreatedAt TIMESTAMP NOT NULL,
  UpdatedAt TIMESTAMP NOT NULL,
  LastExecutionPrice DECIMAL(18,3),
  LastFillQuantity INTEGER
);
CREATE INDEX idx_orderbook_status ON OrderBook(Status);
CREATE INDEX idx_orderbook_updatedat ON OrderBook(UpdatedAt);

CREATE SEQUENCE ACCOUNTS_SEQ START WITH 65000 INCREMENT BY 1;

INSERT INTO Accounts (ID, DisplayName) VALUES (22214, 'Test Account 20');
INSERT INTO Accounts (ID, DisplayName) VALUES (11413, 'Private Clients Fund TTXX');
INSERT INTO Accounts (ID, DisplayName) VALUES (42422, 'Algo Execution Partners');
INSERT INTO Accounts (ID, DisplayName) VALUES (52355, 'Big Corporate Fund');
INSERT INTO Accounts (ID, DisplayName) VALUES (62654, 'Hedge Fund TXY1');
INSERT INTO Accounts (ID, DisplayName) VALUES (10031, 'Internal Trading Book');
INSERT INTO Accounts (ID, DisplayName) VALUES (44044, 'Trading Account 1');

INSERT INTO AccountUsers (AccountID, Username) VALUES (22214, 'user01');
INSERT INTO AccountUsers (AccountID, Username) VALUES (22214, 'user03');
INSERT INTO AccountUsers (AccountID, Username) VALUES (22214, 'user09');
INSERT INTO AccountUsers (AccountID, Username) VALUES (22214, 'user05');
INSERT INTO AccountUsers (AccountID, Username) VALUES (22214, 'user07');
INSERT INTO AccountUsers (AccountID, Username) VALUES (62654, 'user09');
INSERT INTO AccountUsers (AccountID, Username) VALUES (62654, 'user05');
INSERT INTO AccountUsers (AccountID, Username) VALUES (62654, 'user07');
INSERT INTO AccountUsers (AccountID, Username) VALUES (62654, 'user01');
INSERT INTO AccountUsers (AccountID, Username) VALUES (10031, 'user01');
INSERT INTO AccountUsers (AccountID, Username) VALUES (10031, 'user03');
INSERT INTO AccountUsers (AccountID, Username) VALUES (10031, 'user09');
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user09');
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user05');
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user07');
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user04');
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user01');
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user06');

INSERT INTO Trades (ID, Created, Updated, Security, Side, Quantity, Price, State, AccountID) VALUES ('TRADE-22214-AABBCC', NOW(), NOW(), 'IBM', 'Sell', 100, 136.250, 'Settled', 22214);
INSERT INTO Trades (ID, Created, Updated, Security, Side, Quantity, Price, State, AccountID) VALUES ('TRADE-22214-DDEEFF', NOW(), NOW(), 'MS', 'Buy', 1000, 95.125, 'Settled', 22214);
INSERT INTO Trades (ID, Created, Updated, Security, Side, Quantity, Price, State, AccountID) VALUES ('TRADE-22214-GGHHII', NOW(), NOW(), 'C', 'Sell', 2000, 57.500, 'Settled', 22214);
INSERT INTO Trades (ID, Created, Updated, Security, Side, Quantity, Price, State, AccountID) VALUES ('TRADE-52355-AABBCC', NOW(), NOW(), 'BAC', 'Sell', 2400, 41.125, 'Settled', 52355);

INSERT INTO Positions (AccountID, Security, Updated, Quantity, AverageCostBasis) VALUES (22214, 'MS', NOW(), 1000, 95.125);
INSERT INTO Positions (AccountID, Security, Updated, Quantity, AverageCostBasis) VALUES (22214, 'IBM', NOW(), -100, 136.250);
INSERT INTO Positions (AccountID, Security, Updated, Quantity, AverageCostBasis) VALUES (22214, 'C', NOW(), -2000, 57.500);
INSERT INTO Positions (AccountID, Security, Updated, Quantity, AverageCostBasis) VALUES (52355, 'BAC', NOW(), -2400, 41.125);
