DOT = "·"
DASH = "–"

MORSE = {
    [DOT,  DASH]                   => 'A',
    [DASH, DOT,  DOT,  DOT ]       => 'B',
    [DASH, DOT,  DASH, DOT ]       => 'C',
    [DASH, DOT,  DOT ]             => 'D',
    [DOT ]                         => 'E',
    [DOT,  DOT,  DASH, DOT ]       => 'F',
    [DASH, DASH, DOT ]             => 'G',
    [DOT,  DOT,  DOT,  DOT ]       => 'H',
    [DOT,  DOT ]                   => 'I',
    [DOT,  DASH, DASH, DASH]       => 'J',
    [DASH, DOT,  DASH]             => 'K',
    [DOT,  DASH, DOT,  DOT ]       => 'L',
    [DASH, DASH]                   => 'M',
    [DASH, DOT ]                   => 'N',
    [DASH, DASH, DASH]             => 'O',
    [DOT,  DASH, DASH, DOT ]       => 'P',
    [DASH, DASH, DOT,  DASH]       => 'Q',
    [DOT,  DASH, DOT ]             => 'R',
    [DOT,  DOT,  DOT ]             => 'S',
    [DASH]                         => 'T',
    [DOT,  DOT,  DASH]             => 'U',
    [DOT,  DOT,  DOT,  DASH]       => 'V',
    [DOT,  DASH, DASH]             => 'W',
    [DASH, DOT,  DOT,  DASH]       => 'X',
    [DASH, DOT,  DASH, DASH]       => 'Y',
    [DASH, DASH, DOT,  DOT ]       => 'Z',
    [DASH, DASH, DASH, DASH, DASH] => '0',
    [DOT,  DASH, DASH, DASH, DASH] => '1',
    [DOT,  DOT,  DASH, DASH, DASH] => '2',
    [DOT,  DOT,  DOT,  DASH, DASH] => '3',
    [DOT,  DOT,  DOT,  DOT,  DASH] => '4',
    [DOT,  DOT,  DOT,  DOT,  DOT ] => '5',
    [DASH, DOT,  DOT,  DOT,  DOT ] => '6',
    [DASH, DASH, DOT,  DOT,  DOT ] => '7',
    [DASH, DASH, DASH, DOT,  DOT ] => '8',
    [DASH, DASH, DASH, DASH, DOT ] => '9',
}

def decode(morse_signals)
  MORSE[morse_signals] || '?'
end

def bits_to_signals(bit_fractions)
  # dot = 1x1
  # dash = 1x3
  # end_of_signal = 0x1
  # end_of_char = 0x3
  # end_of_word = 0x7
end