import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// Sunnat o Shariah: day-to-day Sunnahs and basic Sharia guidance.
/// Written as general, well-known guidance WITHOUT invented references:
/// where a source is named it is a famous, verifiable one; nothing here
/// claims a specific hadith number unless it is in the Hadith Library.
class SunnahScreen extends StatelessWidget {
  const SunnahScreen({super.key});

  static const _sections = [
    {
      'title': 'Daily Sunnahs',
      'items': [
        'Sleeping after performing Wudu',
        'Using Miswak',
        'Eating with the right hand',
        'Greeting with Salam first',
        'Saying Salam when entering the home',
      ],
    },
    {
      'title': "Friday (Jumu'ah) Sunnahs",
      'items': [
        'Taking a bath (Ghusl)',
        'Wearing clean clothes and applying perfume',
        'Reciting Surah Al-Kahf',
        'Sending Durood abundantly',
        'Going to the mosque early',
      ],
    },
    {
      'title': 'Basics of Sharia',
      'items': [
        'Praying the 5 obligatory prayers on time',
        'Zakat: give 2.5% when wealth reaches the nisab (Zakat Calculator is in the More tab)',
        'Fasting: fasting in Ramadan',
        'Hajj: once in a lifetime if able',
        'Halal income and halal food',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle(
          title: 'Sunnah & Shariah',
          subtitle: 'Daily Sunnahs and basic Sharia guidance.',
        ),
        for (final section in _sections)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in section['items'] as List<String>)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SampleNote(
          text:
              'For detailed matters (differences of opinion, new cases), ask your '
              'mufti or scholar — this section is general guidance, not a fatwa.',
        ),
      ],
    );
  }
}
