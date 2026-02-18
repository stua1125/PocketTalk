enum CardRank {
  two('2', 2), three('3', 3), four('4', 4), five('5', 5),
  six('6', 6), seven('7', 7), eight('8', 8), nine('9', 9),
  ten('T', 10), jack('J', 11), queen('Q', 12), king('K', 13), ace('A', 14);

  final String code;
  final int value;
  const CardRank(this.code, this.value);

  String get displayName {
    return switch (this) {
      CardRank.two => '2',
      CardRank.three => '3',
      CardRank.four => '4',
      CardRank.five => '5',
      CardRank.six => '6',
      CardRank.seven => '7',
      CardRank.eight => '8',
      CardRank.nine => '9',
      CardRank.ten => '10',
      CardRank.jack => 'J',
      CardRank.queen => 'Q',
      CardRank.king => 'K',
      CardRank.ace => 'A',
    };
  }

  static CardRank fromCode(String code) {
    return CardRank.values.firstWhere(
      (r) => r.code.toUpperCase() == code.toUpperCase(),
      orElse: () => throw ArgumentError('Unknown rank code: $code'),
    );
  }
}

enum CardSuit {
  hearts('h', '♥', true),
  diamonds('d', '♦', true),
  clubs('c', '♣', false),
  spades('s', '♠', false);

  final String code;
  final String symbol;
  final bool isRed;
  const CardSuit(this.code, this.symbol, this.isRed);

  static CardSuit fromCode(String code) {
    return CardSuit.values.firstWhere(
      (s) => s.code.toLowerCase() == code.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown suit code: $code'),
    );
  }
}

class PokerCard {
  final CardRank rank;
  final CardSuit suit;

  const PokerCard({required this.rank, required this.suit});

  /// Parse from 2-char code like "Ah" (Ace of Hearts)
  factory PokerCard.fromCode(String code) {
    if (code.length != 2) {
      throw ArgumentError('Card code must be 2 characters: $code');
    }
    return PokerCard(
      rank: CardRank.fromCode(code[0]),
      suit: CardSuit.fromCode(code[1]),
    );
  }

  String get code => '${rank.code}${suit.code}';

  @override
  String toString() => '${rank.displayName}${suit.symbol}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PokerCard && rank == other.rank && suit == other.suit;

  @override
  int get hashCode => rank.hashCode ^ suit.hashCode;
}
