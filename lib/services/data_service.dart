import 'dart:convert';

import 'package:flutter/services.dart';

/// Loaders for the verified static content bundled in assets/data/.
/// All Arabic text in these files was fetched from public sources at
/// build time (see the data report in the project README) — never typed
/// from memory. Fields that could not be verified are simply absent.
class AsmaName {
  final int number;
  final String arabic;
  final String transliteration;
  final String enMeaning;
  final String? urMeaning; // absent when unverified

  const AsmaName({
    required this.number,
    required this.arabic,
    required this.transliteration,
    required this.enMeaning,
    this.urMeaning,
  });

  factory AsmaName.fromJson(Map<String, dynamic> j) => AsmaName(
        number: j['number'] as int,
        arabic: j['arabic'] as String,
        transliteration: j['transliteration'] as String,
        enMeaning: j['enMeaning'] as String,
        urMeaning: j['urMeaning'] as String?,
      );
}

class Dua {
  final String id;
  final String title;
  final String category; // morning-evening | sleeping | waking | eating |
  // home | mosque | travel | difficulty | wudu | manzil | durood | azkar | manzil | durood | azkar | manzil | durood | azkar
  final String arabic;
  final String english;
  final String? urdu; // absent when unverified
  final String reference;
  final int repeat; // prescribed count, 1 = once
  /// True when the `english` field actually holds a Roman
  /// transliteration (not a translation) — the UI labels it as such.
  final bool englishIsTransliteration;
  final String? transliteration; // Roman transliteration, when the file has one
  final String? time; // 'morning' | 'evening' — only for Morning & Evening Azkar

  const Dua({
    required this.id,
    required this.title,
    required this.category,
    required this.arabic,
    required this.english,
    this.urdu,
    required this.reference,
    this.repeat = 1,
    this.englishIsTransliteration = false,
    this.transliteration,
    this.time,
  });

  factory Dua.fromJson(Map<String, dynamic> j) => Dua(
        id: j['id'] as String,
        title: j['title'] as String,
        category: j['category'] as String,
        arabic: j['arabic'] as String,
        english: j['english'] as String,
        urdu: j['urdu'] as String?,
        reference: j['reference'] as String,
        repeat: (j['repeat'] as num?)?.toInt() ?? 1,
        englishIsTransliteration:
            j['englishIsTransliteration'] as bool? ?? false,
        transliteration: j['transliteration'] as String?,
        time: j['time'] as String?,
      );
}

class Hadith {
  final String book; // Sahih al-Bukhari | Sahih Muslim
  final int number;
  final String arabic;
  final String english;
  final String? urdu; // absent when unverified
  final String topic; // Iman | Salah | Akhlaq | Sabr | Ilm |
  // Zakat & Sadaqah | Daily Life

  const Hadith({
    required this.book,
    required this.number,
    required this.arabic,
    required this.english,
    this.urdu,
    required this.topic,
  });

  factory Hadith.fromJson(Map<String, dynamic> j) => Hadith(
        book: j['book'] as String,
        number: j['number'] as int,
        arabic: j['arabic'] as String,
        english: j['english'] as String,
        urdu: j['urdu'] as String?,
        topic: j['topic'] as String,
      );
}

/// One verified salah recitation (Arabic + English + source).
class SalahText {
  final String id; // e.g. sana, ruku, tashahhud
  final String step;
  final String arabic;
  final String english;
  final String reference;
  /// True when the `english` field actually holds a Roman
  /// transliteration (not a translation) — the UI labels it as such.
  final bool englishIsTransliteration;

  const SalahText({
    required this.id,
    required this.step,
    required this.arabic,
    required this.english,
    required this.reference,
    this.englishIsTransliteration = false,
  });

  factory SalahText.fromJson(Map<String, dynamic> j) => SalahText(
        id: j['id'] as String,
        step: j['step'] as String,
        arabic: j['arabic'] as String,
        english: j['english'] as String,
        reference: j['reference'] as String,
        englishIsTransliteration:
            j['englishIsTransliteration'] as bool? ?? false,
      );
}

class DataService {
  static List<AsmaName>? _asma;
  static List<Dua>? _duas;
  static List<Dua>? _manzil;
  static List<Dua>? _durood;
  static List<Dua>? _azkar;
  static List<Hadith>? _hadiths;
  static List<SalahText>? _salahTexts;

  static Future<List<AsmaName>> asma() async {
    if (_asma != null) return _asma!;
    final raw =
        await rootBundle.loadString('assets/data/asma_al_husna.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _asma = list.map(AsmaName.fromJson).toList();
    return _asma!;
  }

  static Future<List<Dua>> duas() async {
    if (_duas != null) return _duas!;
    final raw = await rootBundle.loadString('assets/data/duas.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _duas = list.map(Dua.fromJson).toList();
    return _duas!;
  }

  /// Manzil (protection verses, 16 entries). The file has no
  /// ids/categories, so they are filled in here.
  static Future<List<Dua>> manzil() async {
    if (_manzil != null) return _manzil!;
    final raw = await rootBundle.loadString('assets/data/manzil.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _manzil = list.asMap().entries.map((e) {
      final j = Map<String, dynamic>.of(e.value);
      j['id'] = 'manzil-${e.key + 1}';
      j['category'] = 'manzil';
      return Dua.fromJson(j);
    }).toList();
    return _manzil!;
  }

  /// Durood (salawat collection, 10 entries).
  static Future<List<Dua>> durood() async {
    if (_durood != null) return _durood!;
    final raw = await rootBundle.loadString('assets/data/durood.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _durood = list.asMap().entries.map((e) {
      final j = Map<String, dynamic>.of(e.value);
      j['id'] = 'durood-${e.key + 1}';
      j['category'] = 'durood';
      return Dua.fromJson(j);
    }).toList();
    return _durood!;
  }

  /// Morning & Evening Azkar (45 entries: 23 morning + 22 evening).
  /// Each entry carries its own 'time' field for the sub-filter.
  static Future<List<Dua>> morningEveningAzkar() async {
    if (_azkar != null) return _azkar!;
    final raw =
        await rootBundle.loadString('assets/data/morning_evening_azkar.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _azkar = list.asMap().entries.map((e) {
      final j = Map<String, dynamic>.of(e.value);
      j['id'] = 'azkar-${e.key + 1}';
      j['category'] = 'azkar';
      return Dua.fromJson(j);
    }).toList();
    return _azkar!;
  }

  static Future<List<Hadith>> hadiths() async {
    if (_hadiths != null) return _hadiths!;
    final raw = await rootBundle.loadString('assets/data/hadiths.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _hadiths = list.map(Hadith.fromJson).toList();
    return _hadiths!;
  }

  static Future<List<SalahText>> salahTexts() async {
    if (_salahTexts != null) return _salahTexts!;
    try {
      final raw =
          await rootBundle.loadString('assets/data/salah_texts.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _salahTexts = list.map(SalahText.fromJson).toList();
    } catch (_) {
      _salahTexts = const [];
    }
    return _salahTexts!;
  }
}
