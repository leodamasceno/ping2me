# SQL Script
CREATE DATABASE ping2me;

use ping2me;

CREATE TABLE issues(
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  category VARCHAR(30),
  host VARCHAR(20),
  code VARCHAR(3),
  message VARCHAR(50),
  updated VARCHAR(25),
  status VARCHAR(5)
);

