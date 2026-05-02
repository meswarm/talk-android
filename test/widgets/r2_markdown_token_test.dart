import 'package:flutter_test/flutter_test.dart';
import 'package:talk/r2/r2_ref.dart';
import 'package:talk/widgets/r2_markdown_token.dart';

void main() {
  test('parseR2MarkdownTokens keeps multiline media order', () {
    const text = '![img](r2://b/subhub/imgs/1-a.jpg)\n\n'
        '![clip（视频）](r2://b/subhub/videos/2-b.mp4)\n\n'
        '[track（音频）](r2://b/subhub/audios/3-c_(_).mp3)\n\n'
        '[doc.pdf](r2://b/subhub/files/4-d.pdf)';

    final tokens = parseR2MarkdownTokens(text);

    expect(tokens.length, 4);
    expect(tokens[0].kind, R2MediaKind.image);
    expect(tokens[1].kind, R2MediaKind.video);
    expect(tokens[2].kind, R2MediaKind.audio);
    expect(tokens[3].kind, R2MediaKind.file);
    expect(tokens[2].isImageSyntax, isFalse);
    expect(tokens[3].isImageSyntax, isFalse);
  });

  test('rewriteR2BracketLinksToPreviewCardsMarkdown upgrades bracket r2 links', () {
    const before = '[track（音频）](r2://b/subhub/audios/3-c.mp3)\n'
        '[doc.pdf](r2://b/subhub/files/4-d.pdf)\n'
        '![img](r2://b/subhub/imgs/1-a.jpg)';
    const after = '![track（音频）](r2://b/subhub/audios/3-c.mp3)\n'
        '![doc.pdf](r2://b/subhub/files/4-d.pdf)\n'
        '![img](r2://b/subhub/imgs/1-a.jpg)';

    expect(rewriteR2BracketLinksToPreviewCardsMarkdown(before), after);
  });
}
