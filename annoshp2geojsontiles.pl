use File::Find;
use File::Path;
use Math::Trig;
use utf8;
use Encode;
use Archive::Zip;
use Geo::ShapeFile;
use Data::Dumper;

## 設定 ##
###########################################################################################################
#出力するgeojson tileのzoomlevelを指定
my $zoom=15;
#shpのzipの置き場所を指定（この場所以下のzipを検索）
my $zipdir = 'D://shpzip/';
#取り出すshpのファイル名前に含まれる文字列
my $shpname = '-Anno-';
#取り出したshpの置き場所
my $shpdir = 'D://annoshp/';
#geojsonのpropertiesへ出力するshpの属性項目の設定
my @outproperty = ('rID','lfSpanFr','lfSpanTo','tmpFlg','orgGILvl','ftCode','admCode','devDate','annoCtg','knj','kana','arrng','arrngAgl','repPt','gaiji','noChar','charG1','charG2','charG3','charG4','charG5','charG6','charG7','charG8','charG9','charG10','charG11','charG12','charG13','charG14','charG15','charG16','charG17','charG18','charG19','charG20','charG21','charG22');
#geojsonのpropertiesへ出力するshpの属性項目が文字列か数値かの判別（文字列：0、数値：1）
my %outproperty_num = ('rID' => 0,'lfSpanFr' => 0,'lfSpanTo' => 0,'tmpFlg' => 1,'orgGILvl' => 0,'ftCode' => 0,'admCode' => 0,'devDate' => 0,'annoCtg' => 0,'knj' => 0,'kana' => 0,'arrng' => 1,'arrngAgl' => 1,'repPt' => 1,'gaiji' => 1,'noChar' => 1,'charG1' => 0,'charG2' => 0,'charG3' => 0,'charG4' => 0,'charG5' => 0,'charG6' => 0,'charG7' => 0,'charG8' => 0,'charG9' => 0,'charG10' => 0,'charG11' => 0,'charG12' => 0,'charG13' => 0,'charG14' => 0,'charG15' => 0,'charG16' => 0,'charG17' => 0,'charG18' => 0,'charG19' => 0,'charG20' => 0,'charG21' => 0,'charG22' => 0);
###########################################################################################################


## 以下、プログラム ##
###########################################################################################################

%tlcnt=();#タイルリスト

##zip検索
print "zip search..\n";
#-- ディレクトリを指定（指定フォルダを指定） --#
@directories_to_searchzip = ($zipdir);
#-- 実行 --#
find(\&wantedzip, @directories_to_searchzip);

sub wantedzip{
#  $kariList = $File::Find::dir, '/';    #カレントディレクトリ  
  $kariList = $_;          #ファイル名
 #zipを検索
  if($kariList =~ /\.zip/ ){

   #オブジェクトを作成
   my $zip = Archive::Zip->new();
   #ファイルの読み込みに失敗したら強制終了
   die 'read error' unless $zip->read($kariList) == AZ_OK;
   #ファイルの一覧を取得
   @members = $zip->members();
   foreach (@members) {
   #ファイル名はfileNameにて取得できます。
    my $name = $_->fileName();
    if($name =~ /$shpname/){
     #ファイルをアーカイブから取り出すにはextractMemberもしくは以下のextractMemberWithoutPathsを使用します。
     $zip->extractMemberWithoutPaths($name,$shpdir.$name);
    }
   }

  }
}

##shp検索
print "shp search..\n";
#-- ディレクトリを指定（指定フォルダを指定） --#
@directories_to_searchshp = ($shpdir);
#-- 実行 --#
find(\&wantedshp, @directories_to_searchshp);

sub wantedshp{
#  $kariList = $File::Find::dir, '/';    #カレントディレクトリ  
  $kariList = $_;          #ファイル名
 #shpを検索
  if($kariList =~ /\.shp/ ){
   my @d= split(/\./,$kariList);

my $shapefile = new Geo::ShapeFile($d[0]);
for (1 ..$shapefile->shapes){
    my $shape = $shapefile->get_shp_record($_);
    my %data = $shapefile->get_dbf_record($_); 
    @point = $shape->points;
    foreach $p (@point){
        $L=$p->X;
        $B=$p->Y;
    } 
    my $kari="{ \"type\": \"Feature\",\"geometry\": {\"type\": \"Point\", \"coordinates\": [".$L.",".$B."]},\"properties\": {";
    my @karip =();
    foreach my $p (@outproperty){
     if( defined $data{$p} && $data{$p} ne ""){
      $data{$p} = decode('cp932', $data{$p});
#      if($data{$p} =~ /^\d+$/){
#      if ($data{$p} =~ /^(-|\+)?(\d+\.?\d*|\d*\.?\d+)(E\+(\d+\.?\d*|\d*\.?\d+)|E\-(\d+\.?\d*|\d*\.?\d+))?$/i){
      if($outproperty_num{$p} == 1){
       push(@karip, "\"".$p."\":".$data{$p});
#       push(@karip, "\"".$p."\":\"".$data{$p}."\"");
      }else{
       push(@karip, "\"".$p."\":\"".$data{$p}."\"");
      }
     }else{
      push(@karip, "\"".$p."\":\"\"");
     }
    }
    $kari=$kari.join(',', @karip);
    $kari=$kari."}}";
    
    $key=LB2XY($L,$B,$zoom);
    if ($tlcnt{$key}) {
       $tlcnt{$key}=$tlcnt{$key}.",\n".$kari;
     } else {
       $tlcnt{$key}=$kari;
    }

}

  }
}


##############ファイル書き出し############
print "tile out..\n";
foreach my $key (keys(%tlcnt)){
 @k= split(/\//,$key);
 mkpath("./". @k[0]."/".@k[1]);
 
open(FOUT,">:utf8","./".$key.".geojson");
flock(FOUT,2);
print FOUT<<ENDJSON;
{ "type": "FeatureCollection",
"features": [
$tlcnt{$key}
]
}
ENDJSON
close(FOUT);
}




#真球メルカトル投影変換・タイル座標
use Math::Trig;
sub LB2XY {
my $L=shift;
my $B=shift;
my $zoom=shift;

my $tileSize=256;
my $initialResolution = 2 * pi() / $tileSize;
my $Resolution = $initialResolution / (2**$zoom);
my $originShift = 2 * pi() / 2.0;

my $X=deg2rad($L);
my $Y=log(tan(pi/4 + deg2rad($B)/2));

my $tx=int(($X + $originShift)/($tileSize * $Resolution));
my $ty=int(($Y + $originShift)/($tileSize * $Resolution));
$ty = 2**$zoom - $ty -1;

return ($zoom."/".$tx."/".$ty);
}

