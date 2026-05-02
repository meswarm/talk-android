import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/widgets/composer/markdown_image_link_delete_formatter.dart';

void main() {
  const fmt = MarkdownImageLinkDeleteFormatter();

  test('deletes full image token when backspacing inside alt', () {
    const oldV = TextEditingValue(
      text: '![a](b)',
      selection: TextSelection.collapsed(offset: 3),
    );
    const newV = TextEditingValue(
      text: '![](b)',
      selection: TextSelection.collapsed(offset: 2),
    );
    final out = fmt.formatEditUpdate(oldV, newV);
    expect(out.text, '');
    expect(out.selection.baseOffset, 0);
  });

  test('deletes full image token when backspacing closing paren', () {
    const s =
        '![100.jpg](r2://matrix/attachments/1776498415811-1000013290.jpg)';
    final oldV = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    final newV = TextEditingValue(
      text: s.substring(0, s.length - 1),
      selection: TextSelection.collapsed(offset: s.length - 1),
    );
    final out = fmt.formatEditUpdate(oldV, newV);
    expect(out.text, '');
    expect(out.selection.baseOffset, 0);
  });

  test('deletes bracket r2 video link by file extension without mime query', () {
    const s = '[capture.mp4（视频）](r2://bucket/movie.mp4)';
    final oldV = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    final newV = TextEditingValue(
      text: s.substring(0, s.length - 1),
      selection: TextSelection.collapsed(offset: s.length - 1),
    );
    final out = fmt.formatEditUpdate(oldV, newV);
    expect(out.text, '');
    expect(out.selection.baseOffset, 0);
  });

  test('deletes full legacy bracket r2 video link in one step', () {
    const s = '[capture.mp4（视频）](r2://bucket/videos/1-v.mp4)';
    final oldV = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    final newV = TextEditingValue(
      text: s.substring(0, s.length - 1),
      selection: TextSelection.collapsed(offset: s.length - 1),
    );
    final out = fmt.formatEditUpdate(oldV, newV);
    expect(out.text, '');
    expect(out.selection.baseOffset, 0);
  });

  test('deletes bracket audio when object key contains parentheses', () {
    const s =
        '[song (音频) ](r2://linux-storage/subhub/audios/1776580190426-_DJ_-_(_DJ_)_(_).mp3)';
    final oldV = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    final newV = TextEditingValue(
      text: s.substring(0, s.length - 1),
      selection: TextSelection.collapsed(offset: s.length - 1),
    );
    final out = fmt.formatEditUpdate(oldV, newV);
    expect(out.text, '');
    expect(out.selection.baseOffset, 0);
  });

  test('deletes image token when r2 url contains parentheses in key', () {
    const s = '![shot](r2://b/room/imgs/1-x_(_).png)';
    final oldV = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    final newV = TextEditingValue(
      text: s.substring(0, s.length - 1),
      selection: TextSelection.collapsed(offset: s.length - 1),
    );
    final out = fmt.formatEditUpdate(oldV, newV);
    expect(out.text, '');
    expect(out.selection.baseOffset, 0);
  });

  test('deletes bracket r2 audio link in one step', () {
    const s = '[track（音频）](r2://bucket/audios/1-t.mp3)';
    final oldV = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    final newV = TextEditingValue(
      text: s.substring(0, s.length - 1),
      selection: TextSelection.collapsed(offset: s.length - 1),
    );
    final out = fmt.formatEditUpdate(oldV, newV);
    expect(out.text, '');
    expect(out.selection.baseOffset, 0);
  });

  test('deleting one media token does not swallow previous multiline tokens', () {
    const img = '![10000013230.jpg](r2://linux-storage/subhub/imgs/1776581234482-10000013230.jpg)';
    const video =
        '![10000009240.mp4（视频）](r2://linux-storage/subhub/videos/1776581243933-10000009240.mp4)';
    const audio =
        '![抖音热歌DJ - 我还年轻（抖音DJ版）(翻自 老王乐队).mp3（音频）](r2://linux-storage/subhub/audios/1776581251727-_DJ_-_(_DJ_)_(_).mp3)';
    const text = '$img\n\n$video\n\n$audio';
    final oldV = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    final newV = TextEditingValue(
      text: text.substring(0, text.length - 1),
      selection: TextSelection.collapsed(offset: text.length - 1),
    );
    final out = fmt.formatEditUpdate(oldV, newV);
    expect(out.text, '$img\n\n$video\n\n');
  });

  test('deletes full video-as-image token (same syntax as images)', () {
    const s = '![clip.mp4（视频）](r2://bucket/videos/1-v.mp4)';
    final oldV = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
    final newV = TextEditingValue(
      text: s.substring(0, s.length - 1),
      selection: TextSelection.collapsed(offset: s.length - 1),
    );
    final out = fmt.formatEditUpdate(oldV, newV);
    expect(out.text, '');
    expect(out.selection.baseOffset, 0);
  });

  test('does not affect plain text delete', () {
    const oldV = TextEditingValue(
      text: 'hello',
      selection: TextSelection.collapsed(offset: 5),
    );
    const newV = TextEditingValue(
      text: 'hell',
      selection: TextSelection.collapsed(offset: 4),
    );
    final out = fmt.formatEditUpdate(oldV, newV);
    expect(out.text, 'hell');
  });
}
