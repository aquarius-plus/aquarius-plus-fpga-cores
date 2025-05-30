# Per operator (36x)

| 31  | 30  | 29  | 28  | 27:24 | 23:22 | 21:16 | 15:8 | 11:8 | 7:4 | 3:0 |
| :-: | :-: | :-: | :-: | :---: | :---: | :---: | :--: | :--: | :-: | --- |
| AM  | VIB | EGT | KSR | MULT  |  KSL  |  TL   |  AR  |  DR  | SL  | RR  |

| 31:3 | 2:0 |
| :--: | --- |
|  -   | WS  |

| Count | Width | Name | Description                    |
| ----: | ----: | ---- | ------------------------------ |
|    18 |     1 | AM   | Amplitude modulation (Tremelo) |
|    18 |     1 | VIB  | Vibrato                        |
|    18 |     1 | EGT  | Envelope type: 0:ADR 1:ADSR    |
|    18 |     1 | KSR  | Key scale rate                 |
|    18 |     4 | MULT | Frequency data multiplier      |
|    18 |     2 | KSL  | Key scale level                |
|    18 |     6 | TL   | Total level                    |
|    18 |     4 | AR   | Attack Rate                    |
|    18 |     4 | DR   | Decay Rate                     |
|    18 |     4 | SL   | Sustain Level                  |
|    18 |     4 | RR   | Release Rate                   |
|    18 |     3 | WS   | Wave select                    |

# Per channel (18x)

| 31:22 | 21  | 20  | 19:17 | 16  | 15:14 | 13  | 12:10 | 9:0  |
| :---: | :-: | :-: | :---: | :-: | :---: | :-: | :---: | :--: |
|   -   | CHB | CHA |  FB   | CNT |   -   | KON | BLOCK | FNUM |

| Count | Width | Name  | Description                              |
| ----: | ----: | ----- | ---------------------------------------- |
|     9 |     1 | CHB   | Mix to channel B                         |
|     9 |     1 | CHA   | Mix to channel A                         |
|     9 |     3 | FB    | Modulation depth for slot 1 FM feed back |
|     9 |     1 | CNT   | Operation connection (algorithm)         |
|     9 |     1 | KON   | Key on                                   |
|     9 |     3 | BLOCK | Octave data                              |
|     9 |    10 | FNUM  | Frequency number (10 bit)                |

10+3+1+2+3+1+1=21

# Global

| 31:16 | 15  | 14  | 13  | 12  | 11  | 10  |  9  |  8  | 7:6 | 5:0 |
| :---: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
|   -   | DAM | DVB | RYT | BD  | SD  | TOM | TC  | HH  |  -  | 4OP |

| Count | Width | Name           | Description                |
| ----: | ----: | -------------- | -------------------------- |
|     1 |     1 | DAM            | Amplitude modulation depth |
|     1 |     1 | DVB            | Vibrato depth              |
|     1 |     1 | RYT            | Rhythm sound mode          |
|     1 |     1 | BD             | Bass drum                  |
|     1 |     1 | SD             | Snare drum                 |
|     1 |     1 | TOM            | Tom tom                    |
|     1 |     1 | TC             | Top-cymbal                 |
|     1 |     1 | HH             | Hi-hat                     |
|     1 |     6 | CONNECTION SEL | Four-operator mode         |
