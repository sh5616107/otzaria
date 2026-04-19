import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/links.dart';

void main() {
  test('fallbackDisplayReference מחזיר טקסט סינכרוני עם שם הספר', () {
    final link = Link(
      heRef: 'פרק א',
      index1: 1,
      path2: 'בראשית',
      index2: 1,
      connectionType: 'REFERENCE',
    );

    expect(link.fallbackDisplayReference, contains('בראשית'));
    expect(link.fallbackDisplayReference, contains('פרק א'));
  });

  test('getLinksforIndexs שומר קישורים נפרדים משורות מקור שונות', () async {
    final links = [
      Link(
        heRef: 'רש"י פסוק א',
        index1: 22,
        path2: 'רש"י על בראשית',
        index2: 5,
        connectionType: 'COMMENTARY',
      ),
      Link(
        heRef: 'רש"י פסוק א',
        index1: 23,
        path2: 'רש"י על בראשית',
        index2: 5,
        connectionType: 'COMMENTARY',
      ),
    ];

    final result = await getLinksforIndexs(
      indexes: const [21, 22],
      links: links,
      commentatorsToShow: const ['רש"י על בראשית'],
    );

    expect(result, hasLength(2));
    expect(result.first.path2, 'רש"י על בראשית');
    expect(result.first.index2, 5);
  });
}
