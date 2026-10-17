/// Every tunable number of the game in one place.
abstract final class Rules {
  // Economy
  static const int unitCost = 4;
  static const int unitsPerUpkeepGold = 4;
  static const int baseIncome = 4;

  /// A province raises at most this many units per turn, plus its income.
  static const int recruitBase = 2;

  // Combat
  static const double defenseBonus = 1.5;
  static const double capitalBonus = 0.5;

  /// Locals who fight beside the garrison of their own province. They cannot
  /// be moved and are back at full strength every turn: this base, plus the
  /// province's income times [militiaPerIncome].
  static const int militiaBase = 2;
  static const double militiaPerIncome = 0.5;

  /// Each side's strength is scaled by a roll in [1 - spread, 1 + spread].
  static const double combatSpread = 0.15;

  // Building. One project per province per turn, finished at once.
  /// Each level of fortification adds this to a defender's cover.
  static const double fortBonus = 0.5;
  static const int maxFort = 2;

  /// Gold for a fort level: this times the level it reaches.
  static const int fortCost = 40;

  /// Gold a turn for every fort level standing.
  static const int fortUpkeep = 1;

  /// Development adds 1 income a level, up to [maxDevelop] levels. The first
  /// costs [developCost], each further one [developStep] more.
  static const int maxDevelop = 5;
  static const int developCost = 20;
  static const int developStep = 15;

  // Technology
  /// Gold for a level: the nation's income for this many turns, times the
  /// level it reaches. So the share of income put into research, not the
  /// size of the realm, sets the pace.
  static const int techCost = 2;
  static const int maxTech = 10;

  /// Each army level makes every unit fight this much harder, in attack and
  /// defence alike.
  static const double armyTechBonus = 0.05;

  /// Each industry level adds this share to the income.
  static const double industryTechBonus = 0.04;

  /// The shares of income, in percent, that can go into research.
  static const List<int> researchShares = [0, 10, 20, 30, 50];

  // Occupation
  /// A province taken from the nation that held it in the scenario yields
  /// this share of its income at first, and all of it after
  /// [integrationTurns]. Its first owner gets it back whole.
  static const double occupiedShare = 0.5;
  static const int integrationTurns = 24;

  // Unrest
  /// Each turn, an occupied province held by fewer units than its militia
  /// rises with this chance, scaled by how far short the garrison falls.
  static const double revoltChance = 0.015;

  /// Rebels who take the province: this many times its militia.
  static const double rebelsPerMilitia = 1.5;

  // Diplomacy
  static const int truceTurns = 8;

  /// A peace or alliance offer stays on the table for this many end-of-turns.
  static const int peaceOfferTurns = 2;

  // Game setup
  static const double startArmyPerIncome = 1.6;
  static const int startArmyPerProvince = 1;
  static const int startGoldPerIncome = 2;
  static const double defaultWinFraction = 0.4;

  // Difficulty
  /// What the AI nations earn, against a normal income, on each difficulty
  /// from easiest to hardest. The player always earns the normal income.
  static const List<double> aiIncome = [0.8, 1.0, 1.25];
  static const int normalDifficulty = 1;

  // AI
  static const double aiAttackMargin = 1.2;
  static const double aiWarRatio = 1.8;
  static const int aiMinWarTurns = 6;
  static const int aiStalemateTurns = 10;

  /// Every turn at peace makes the AI accept worse odds for its next war by
  /// this share of [aiWarRatio], down to [aiRestlessMax] of it. Without this
  /// two evenly matched empires would face each other in peace forever.
  static const double aiRestlessPerTurn = 0.02;
  static const double aiRestlessMax = 0.6;

  /// At peace the AI keeps its army at this share of what income can pay
  /// for, and at [aiWarArmy] once it is at war or sits on a full treasury.
  static const double aiPeaceArmy = 0.7;
  static const double aiWarArmy = 0.95;
  static const int aiFullTreasuryTurns = 8;

  /// The AI keeps no more allies than this.
  static const int aiMaxAlliances = 3;

  /// After proposing an alliance, the AI waits this many turns before it
  /// asks the same nation again.
  static const int aiAllianceRetryTurns = 12;

  /// Share of income, in percent, the AI puts into research at peace and
  /// at war.
  static const int aiResearchPeace = 20;
  static const int aiResearchWar = 10;
}
