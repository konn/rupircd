=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.6 2009-08-11T23:45:52+09:00
  
  Copyright (c) 2009 Hiromi Ishii
  
  You can redistribute it and/or modify it under the same term as Ruby.


== これは何？
Pure Ruby で書かれた ircd モドキです。
こんな特徴があります。

* WEBrick を使ってます。
* 100% ruby なのでruby さえあれば何処でも動く
  * コンパイル不要！
* Relay しないので軽い！
  * Relay しないと意味のないコマンドは実装してません。
    * LINK とか STATS l とか
    * &で始まるチャンネル(ローカルチャンネル)
* 設定が簡単！


以下のようなことが出来ません。というか実装予定がありません。

* Relay
  * それに関連したコマンド
* チャンネルマスク

Relay しないのでPseudoです。

これを作る上で、rice の irc.rb を一部改変させて使わせて頂いてます。ありがとうございました！

== こんなあなたに
* 自作ボットをテストしたいがサーバーに負荷を掛けたくない。
* 内輪でサーバを建てたい
* 軽いircdを探してる
* ruby で書かれたものじゃないとやだ！
* 作者の個人的フアン(!?)

== 使い方
ruby ircd.rb sample.conf

詳しくは、 USAGE.ja.rd を 御覧下さい。

== TODO
(1) もっとカッコイイ名前をかんがえる
(2) コマンドを全部(リンク周り以外)実装する
(3) インストーラを作る
(4) セーフチャンネル
(5) 「サービス」機能


== 謝辞
* rice (http://arika.org/ruby/rice)
* WEBrick
* ruby

=end