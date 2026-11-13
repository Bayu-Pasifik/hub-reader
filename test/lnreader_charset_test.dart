import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/novels/lnreader/http_bridge.dart';

void main() {
  test('GBK (lewenn), with charset aliases and quotes', () {
    const nihao = [0xC4, 0xE3, 0xBA, 0xC3];
    expect(decodeBody(nihao, 'gbk'), '你好');
    expect(decodeBody(nihao, 'GB2312'), '你好');
    expect(decodeBody(nihao, '"gb18030"'), '你好');
  });

  test('broken GBK does not throw', () {
    expect(decodeBody([0xC4, 0xE3, 0xBA], 'gbk'), startsWith('你'));
  });

  test('Shift_JIS, EUC-JP and windows-125x', () {
    expect(decodeBody([0x93, 0xFA, 0x96, 0x7B], 'shift_jis'), '日本');
    expect(decodeBody([0xC6, 0xFC, 0xCB, 0xDC], 'euc-jp'), '日本');
    expect(decodeBody([0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2], 'windows-1251'), 'Привет');
    expect(decodeBody([0x80, 0xE9], 'windows-1252'), '€é');
  });

  test('EUC-KR is left to UTF-8 (the package decoder is wrong)', () {
    expect(decodeBody([0xC3, 0xA9], 'euc-kr'), 'é');
  });

  test('UTF-8, Latin-1 and unknown charsets', () {
    expect(decodeBody([0xC3, 0xA9], 'utf-8'), 'é');
    expect(decodeBody([0xE9], 'iso-8859-1'), 'é');
    expect(decodeBody([0xC3, 0xA9], 'x-unknown'), 'é');
    expect(decodeBody([0xC3, 0xA9], null), 'é');
  });
}
