# dkgshp2geojsontiles
電子国土基本図shpのgeojsontiles変換

電子国土基本図のシェープファイルをベクトルタイル（geojson tiles）に変換するPerlプログラムです。

Perlプログラムは、指定したフォルダ内のzipファイル群から指定したshpファイルを取り出し、保存し、ベクトルタイル（geojson tiles）に変換します。

シェープファイルの読み込みにGeo::ShapeFileモジュールを利用します。

Geo::ShapeFileモジュール：
http://search.cpan.org/~slaffan/Geo-ShapeFile-2.60/lib/Geo/ShapeFile.pm

電子国土基本図（数値地図（国土基本情報））の仕様：
http://www.gsi.go.jp/common/000093949.pdf

## points→geojson tiles
電子国土基本図の注記shp（points）を変換するツール（annoshp2geojsontiles.pl）

## lines→geojson tiles
電子国土基本図の河川中心線shp（lines）を変換するツール（rvrclshp2geojsontiles.pl）

電子国土基本図の鉄道中心線shp（lines）を変換するツール（railclshp2geojsontiles.pl）

電子国土基本図の道路中心線shp（lines）を変換するツール（rdclshp2geojsontiles.pl）

rdclshp2geojsontiles.pl は、指定したフォルダ内のzipファイル群から指定したshpファイルを取り出し、保存し、shpファイル毎のjsonファイルを作成し、ベクトルタイル（geojson tiles）に変換します。

## 更新履歴
20150708　新規作成
