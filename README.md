iPHone Application ThirdExample
============
OpenGL ES2によるShaderを用いた描画サンプルプログラムを作成する.
iPhone画面上の正方形領域をメッシュに分けて, メッシュ頂点をランダムに移動する.
その変形された領域にTexture画像を貼付けて表示する.

ファイル ViewController.m が本体で, VertexShader.vsh, FragmentShader.vshがシェーダープログラムである.
あとは設定のおまじないと思えば良い. ファイル一式は https://github.com/ymizoguchi/ThirdExample (githubレポジトリ)へ
公開している. シェーダープログラムで座標変換とTextureの張り付けを行う. プログラム本体では点座標とTexture座標のリスト, 
変換行列をシェーダーに与える. マウスクリックも理解し, 頂点の移動と固定をトグルで行う. クリック時の効果音も入れた. 
解説はブログ https://logic.math.kyushu-u.ac.jp/wiki/pages/a4e4z3w/Xcode_OpenGL_ES2_Texture_Mapping.html に公開中.

Yoshihro Mizoguchi
2013/08/19
