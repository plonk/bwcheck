bwcheck -- YP4G uptest 用帯域測定クライアント
---------------------------------------------

データは ~/.bwcheckrc に保存します。

インストール:

使っているライブラリは Nokogiri と Thor です。

  $ gem install nokogiri thor

bwcheck に実行ビットを付けてパスの通っているところに置いてください。

  $ install -m 755 bwcheck.rb ~/bin/bwcheck

など。

使用例:

    $ bwcheck add tp http://temp.orz.hm/yp/	# TP を追加
    $ bwcheck add sp http://bayonet.ddo.jp/sp/	# SP を追加
    $ bwcheck list				# 登録した YP 一覧
    tp: http://temp.orz.hm/yp/
    sp: http://bayonet.ddo.jp/sp/
    $ bwcheck show tp				# TP での測定情報
    $ bwcheck check sp				# SP で測定
    $ bwcheck check				# 未測定の YP で測定
    $ bwcheck check --force			# 全ての YP で再測定
