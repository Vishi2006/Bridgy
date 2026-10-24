import 'package:bridgy/services/macro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('picks the app named in the goal, defaults to Chrome', () {
    expect(Macro.forGoal('book a cab to Manipal on Rapido').label, 'Rapido');
    expect(Macro.forGoal('order milk on Blinkit').packageName,
        'com.grofers.customerapp');
    expect(Macro.forGoal('order chips from Zepto').label, 'Zepto');
    expect(Macro.forGoal('search for weather').packageName, 'com.android.chrome');
  });

  test('macro starts by launching the app and ends with taps only', () {
    final steps = Macro.forGoal('book a cab to Manipal on Rapido').steps(
      'book a cab to Manipal on Rapido',
    );
    expect(steps.first.raw, isTrue);
    expect(
      steps.first.command,
      'monkey -p com.rapido.passenger -c android.intent.category.LAUNCHER 1',
    );
    expect(steps.where((s) => s.raw).length, 1);
    expect(steps.any((s) => s.command.startsWith('input tap ')), isTrue);
  });

  test('search text is stripped to an adb-safe token', () {
    String typed(String goal) => Macro.forGoal(goal)
        .steps(goal)
        .firstWhere((s) => s.command.startsWith('input text '))
        .command;

    expect(typed('book a cab to Manipal on Rapido'), 'input text "Manipal"');
    expect(typed('order milk on Blinkit'), 'input text "milk"');
    expect(typed('order 1kg rice; rm -rf / on Blinkit'),
        'input text "1kg%srice%srm%srf"');
    expect(typed('book a cab to Manipal, Karnataka'),
        'input text "Manipal%sKarnataka"');
  });
}
