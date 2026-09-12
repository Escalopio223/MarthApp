import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marth_app/features/leisure/presentation/widgets/leisure_rating_slider.dart';

void main() {
  testWidgets('LeisureRatingSlider displays Sin calificar when initialRating is null',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LeisureRatingSlider(
            initialRating: null,
            onRatingChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Tu Puntuación'), findsOneWidget);
    expect(find.text('Sin calificar'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('LeisureRatingSlider displays formatted rating and allows clearing',
      (tester) async {
    double? ratingValue = 8.7;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return LeisureRatingSlider(
                initialRating: ratingValue,
                onRatingChanged: (val) {
                  setState(() => ratingValue = val);
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('8.7 / 10'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Tap clear button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(ratingValue, isNull);
    expect(find.text('Sin calificar'), findsOneWidget);
  });
}
