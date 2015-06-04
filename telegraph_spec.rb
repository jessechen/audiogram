require './telegraph'

describe 'telegraph' do
  it 'should decode morse signal arrays' do
    expect(decode([DOT])).to eq('E')
    expect(decode([DOT, DOT, DOT])).to eq('S')
    expect(decode([DASH, DOT, DOT, DOT, DOT])).to eq('6')
    expect(decode([DOT, DOT, DASH, DASH])).to eq('?')
  end

  it 'should convert bits into morse signal arrays' do
    expect(bits_to_signals([1])).to eq([[DOT]])
    expect(bits_to_signals([1, 1, 1])).to eq([[DASH]])
    expect(bits_to_signals([1, 0, 1])).to eq([[DOT, DOT]])
    expect(bits_to_signals([1, 0, 1, 1, 1])).to eq([[DOT, DASH]])
  end

  it 'should split words on runs of three zeros' do
    expect(bits_to_signals([1, 0, 0, 0, 1])).to eq([[DOT], [DOT]])
    expect(bits_to_signals([1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1])).to eq([[DASH, DOT], [DASH], [DOT]])
  end

  it 'should treat runs of two ones as dots and runs of four or more ones as dashes' do
    expect(bits_to_signals([1, 1])).to eq([[DOT]])
    expect(bits_to_signals([1, 1, 1, 1])).to eq([[DASH]])
    expect(bits_to_signals([1, 1, 1, 1, 1, 0, 0, 1, 1])).to eq([[DASH, DOT]])
    expect(bits_to_signals([1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1])).to eq([[DASH], [DOT]])
  end
end