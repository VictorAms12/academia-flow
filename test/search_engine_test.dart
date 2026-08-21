import 'package:academia_flow/utils/search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza acentos e espaços', () {
    expect(normalizeSearchText('  Lógica   de Programação  '), 'logica de programacao');
  });

  test('busca com múltiplos termos encontra campos diferentes', () {
    final score = searchScore(
      'banco normalizacao',
      ['Banco de Dados', 'Resumo sobre normalização e formas normais'],
    );
    expect(score, greaterThanOrEqualTo(0));
  });

  test('busca exige todos os termos', () {
    expect(
      searchScore('java grafos', ['Java POO', 'Classes e objetos']),
      -1,
    );
  });

  test('título exato recebe maior relevância que ocorrência secundária', () {
    final exact = searchScore('sql', ['SQL', 'Banco de dados']);
    final secondary = searchScore('sql', ['Banco de dados', 'Introdução a SQL']);
    expect(exact, greaterThan(secondary));
  });
}
