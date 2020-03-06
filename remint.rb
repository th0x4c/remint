#!/usr/bin/ruby
# -*- coding: utf-8 -*-
# == Name
# remint.rb -- Make Coin output into Excel output
#
# == Synopsis
# Coin のログファイルを Excel 形式などに変換する
#
# == Usage
#
# ruby remint.rb [ -o | --output <file_prefix> ] [ -b | --begin <time> ] [ -e | --end <time> ] [ -c | --category <category_list> ] [ -f | --file <config_file> ] [ -T | --format <format_name> ] [ -h ] [ -H | --help ] <coin_log_file>...
#
# -o | --output <file_prefix> ::
#   出力ファイルの接頭字を指定.(必須)
#
# -b | --begin <time> ::
#   開始時刻を指定.
#   開始時刻以降のログ出力が対象になる.
#
# -e | --end <time> ::
#   終了時刻を指定.
#   終了時刻以前のログ出力が対象になる.
#
# -c | --category <category_list> ::
#   出力するカテゴリ名を CSV 形式で指定.
#
# -f | --file <config_file> ::
#   config ファイルを指定.
#
# -T | --format <format_name> ::
#   出力フォーマットを指定.
#   xls (デフォルト) または csv.
#
# -h | --help ::
#   ヘルプを出力.
#
# == Example
#
# * 最もシンプルな例
#     ruby remint.rb -o output ./coin_log_2009-03-20T*/dbstat/dbstat*
# * オプション指定の例
#     ruby remint.rb -o output -b \"2009-03-20 15:30\" -e \"2009-03-20 16:30\" -c SGASTAT,SYSSTAT ./dbstat*
# * 各カテゴリ毎の CSV ファイルを出力
#     ruby remint.rb -o output -T csv ./dbstat*
#
# == Config File
#
# config ファイルは YAML 形式のファイルです.
# remint.rb 末尾の __END__ 以下を編集するか, 別ファイルで作成して -f オプションで
# 指定してください.
#
# 以下が例です.
# このようにカテゴリ名(name), 差分を出力したい行(diff),
# Excel のピボットテーブル, グラフの指定(pivot) を行います.
# 特に diff, pivot が必要ないカテゴリについては記載は必要ありません.
#
#   --- # config ファイル
#   - name: SGASTAT                  # カテゴリ名(CNAME 列の値)
#     diff:                          # 前回採取時刻からの差分を出力する場合に指定(オプション)
#       id:                            # 一意性を識別するためのcolumnを指定
#         - POOL
#         - NAME
#       value:                         # 差分を取る column名を指定(複数列挙可能)
#         - BYTES
#     pivot:                         # ピボットテーブルを作成する場合に指定(オプション)
#       RowField: PTIME                # 行フィールド
#       ColumnField: NAME              # 列フィールド
#       DataField: BYTES               # データフィールド 差分を出力したい場合は上記 diff を設定して "diff_<value名>" を指定.
#       PageField: POOL                # ページフィールド
#       CurrentPage: shared pool       # デフォルトのページの値(ページフィールドで取り得る値から指定)
#
#   - name: SYSTEM_EVENT
#     diff:
#       id:
#         - EVENT
#       value:
#         - TOTAL_WAITS                # 差分を取る列はこのように複数指定可能
#         - TIME_WAITED_MICRO
#     pivot:
#       RowField: PTIME
#       ColumnField: EVENT
#       DataField: diff_TIME_WAITED_MICRO
#       PageField: CNAME               # 特に指定したいページフィールドがなければ
#       CurrentPage: SYSTEM_EVENT      # このように CNAME, <category名> を指定する
#
# == Copyright
# Copyright (C) 2009, 2015, Takashi Hashizume All rights reserved.
# Distributed under the BSD License.
#
# == Modified
# Takashi Hashizume 03/01/2015 - Rename to "remint"
# Takashi Hashizume 03/21/2009 - Alpha Release

# IS_WINDOWS : Global 変数
if IS_WINDOWS = RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|cygwin|bccwin/
  require 'win32ole'
  module Excel
  end
  Encoding.default_external = Encoding::UTF_8
else
end

require 'yaml'
require 'csv'
require 'optparse'
require 'time'
require 'zlib'

class ExcelSheet
  BUFFER_ROW_LEN     = 1024       # バッファする行数
  MAX_SHEET_NAME_LEN = 31         # Excel のシート名の最大文字数
  MAX_STR_LEN        = 254        # Excel のセル毎の最大文字数
  MAX_ROWS           = 65536 * 16 # Excel の最大行数
  FONT_SIZE          = 8          # フォントサイズ
  COLUMN_WIDTH       = 12         # 列サイズ

  def initialize(excel_sheet, name)
    @sheet = excel_sheet
    @sheet.Name = name[0, MAX_SHEET_NAME_LEN]

    @buffer = Array.new
    @row = 0 # 出力済みの行数
  end

  def puts(output_ary)
    output_ary = output_ary.map {|x| x.to_s.length > MAX_STR_LEN ? x[0, MAX_STR_LEN] : x}
    @buffer.push(output_ary)

    if @buffer.length >= BUFFER_ROW_LEN
      flush
    end
  end

  def close
    flush
    @sheet.Cells.Font.Size = FONT_SIZE
    @sheet.Cells.ColumnWidth = COLUMN_WIDTH
  end

  private
  def flush
    return if @buffer.length == 0 || @row > MAX_ROWS

    begin_row = @row + 1
    end_row = @row + @buffer.length

    # Excel の最大行数を超える場合は, @buffer を削って超えないように調整する.
    # その場合, Warning を出力.
    if end_row > MAX_ROWS
      STDERR.puts "Warning: sheet #{@sheet.Name} exceeded #{MAX_ROWS} rows.\n" +
                  "         omit \"#{@buffer[MAX_ROWS - begin_row + 1].join(", ")}\"..."
      end_row = MAX_ROWS
    end

    if begin_row <= MAX_ROWS
      @sheet.Range(@sheet.Cells(begin_row, 1), @sheet.Cells(end_row, @buffer[0].length)).Value = @buffer
    end

    @row += @buffer.length
    @buffer = []
  end
end

class OutputManager
  def initialize(mgr_name)
  end

  def puts(name, output_ary)
  end

  def close
  end

  private
  def add_output(name)
  end
end

class CSVOutputManager < OutputManager
  def initialize(mgr_name)
    @file_prefix = mgr_name
    @outputs = Hash.new
  end

  def puts(name, output_ary)
    if @outputs[name].nil?
      @outputs[name] = File.open("#{@file_prefix}_#{name}.csv", "w")
    end

    @outputs[name].puts(CSV.generate_line(output_ary))
  end

  def close
    @outputs.each_value {|v| v.close}
  end
end

class ExcelOutputManager < OutputManager
  MAX_SHEET_NAME_LEN = 31 # Excel のシート名の最大文字数
  FONT_SIZE          = 8  # フォントサイズ
  COLUMN_WIDTH       = 12 # 列サイズ

  def initialize(mgr_name)
    @filename = get_abs_path("#{mgr_name}.xlsx") # 出力ファイル名
    @excel = WIN32OLE.new("excel.application") # Excel オブジェクト
    WIN32OLE.const_load(@excel, Excel)
    @excel.Visible = true
    @excel.SheetsInNewWorkbook = 1
    @excel.Workbooks.Add
    @outputs = Hash.new
  end

  def puts(name, output_ary)
    if @outputs[name].nil?
      add_output(name)
    end

    @outputs[name].puts(output_ary)
  end

  def pivot(name, pivot_conf)
    return unless @outputs.key?(name)

    pivot_sheet = @excel.Sheets.Add('After' => @excel.Sheets(name))
    pivot_sheet.Name =  "#{name} Pivot"[0, MAX_SHEET_NAME_LEN]

    sheet = @excel.Sheets(name)
    @outputs[name].close

    pivot_sheet.Name =  "Pivot #{name}"[0, MAX_SHEET_NAME_LEN].gsub(/ /, '')
    col_end = sheet.UsedRange.Columns.Count.to_i
    @excel.ActiveWorkBook
          .PivotCaches
          .Create({'SourceType' => Excel::XlDatabase,
                   'SourceData' => sheet.Name.to_s + '!' + "R1C1:R1048576C#{col_end.to_s}",
                   'Version'    => Excel::XlPivotTableVersion14})
          .CreatePivotTable({'TableDestination' => pivot_sheet.Name.to_s + '!' + 'R3C1',
                             'TableName'        => "pivot table 1",
                             'DefaultVersion'   => Excel::XlPivotTableVersion14})

    pivot_table = pivot_sheet.PivotTables("pivot table 1")
    pivot_table.PivotFields(pivot_conf['PageField']).Orientation = Excel::XlPageField
    pivot_table.PivotFields(pivot_conf['PageField']).CurrentPage = pivot_conf['CurrentPage']
    pivot_table.PivotFields(pivot_conf['RowField']).Orientation = Excel::XlRowField

    [pivot_conf['ColumnField']].flatten.each do |column_field|
      pivot_table.PivotFields(column_field).Orientation = Excel::XlColumnField
    end

    [pivot_conf['DataField']].flatten.each do |data_field|
      pivot_table.AddDataField(pivot_table.PivotFields(data_field),
                               "Sum / #{data_field}",
                               Excel::XlSum)
    end

    pivot_conf['invisible'].to_a.each do |fi|
      fi['item'].each do |item|
        pivot_table.PivotFields(fi['field']).PivotItems(item).Visible = false
      end
    end

    pivot_conf['visible'].to_a.each do |fi|
      pivot_table.PivotFields(fi['field']).PivotItems.each do |item|
        unless fi['item'].include?(item.Value)
          item.Visible = false
        end
      end
    end

    if pivot_conf['PivotFilters']
       filter = pivot_conf['PivotFilters']

       pivot_table.PivotFields([pivot_conf['ColumnField']].flatten[0])
                  .PivotFilters
                  .Add({'Type'      => eval(filter['Type']),
                        'DataField' => pivot_table.PivotFields("Sum / #{[pivot_conf['DataField']].flatten[0]}"),
                        'Value1'    => filter['Value1']})
    end

    pivot_sheet.Cells.Font.Size = FONT_SIZE
    pivot_sheet.Cells.ColumnWidth = COLUMN_WIDTH

    chart = @excel.Charts.Add
    chart.Name = "#{name} Graph"[0, MAX_SHEET_NAME_LEN]
    chart.Location({'Where' => Excel::XlLocationAsNewSheet})
    chart_type = pivot_conf['ChartType'] ? eval(pivot_conf['ChartType']) : Excel::XlLineMarkers
    chart.ChartType = chart_type

    chart.Axes(1).CrossesAt = Excel::XlCategory
    last_row = pivot_sheet.Range("a65536").End(Excel::XlUp).Row
    chart.Axes(1).TickLabelSpacing = last_row.to_i / 10 + 1
    chart.Axes(1).TickMarkSpacing = 1
    chart.Axes(1).AxisBetweenCategories = true
    chart.Axes(1).ReversePlotOrder = false

    chart.Axes(1).TickLabels.Alignment = Excel::XlCenter
    chart.Axes(1).TickLabels.Offset = 100
    chart.Axes(1).TickLabels.ReadingOrder = Excel::XlContext
    chart.Axes(1).TickLabels.Orientation = Excel::XlDownward

    chart.HasTitle = true
    chart.ChartTitle.Characters.Text = name

    chart.Legend.Font.Size = FONT_SIZE
    chart.Axes(Excel::XlCategory).TickLabels.Font.Size = FONT_SIZE
    chart.Axes(Excel::XlValue).TickLabels.Font.Size = FONT_SIZE
    chart.Axes(Excel::XlValue).TickLabels.NumberFormatLocal = "0_ "
  end

  def close
    @outputs.each_value {|v| v.close}

    @excel.ActiveWorkBook.SaveAs(@filename)
    @excel.ActiveWorkBook.Close(0)
    @excel.Quit()
  end

  private
  # ファイルパスの絶対パスを取得
  def get_abs_path(filename)
    fso = WIN32OLE.new('Scripting.FileSystemObject')
    return fso.GetAbsolutePathName(filename)
  end

  def add_output(name)
    if @outputs[name].nil?
      # 末尾にシート追加
      last_sheet = @excel.Sheets(@excel.Sheets.Count)
      @outputs[name] = ExcelSheet.new(@excel.Sheets.Add('After' => last_sheet), name)
    end
  end
end

class Remint
  CNAME_INDEX = 0 # CNAME 列の列番号
  PTIME_INDEX = 1 # PTIME 列の列番号

  attr_writer :output_manager

  attr_writer :categories # 出力対象のカテゴリ名の配列. nil の場合は全て出力.

  def initialize(config)
    @config = config
    @lines = ["", "", ""] # 3行分の情報
    @headers = Hash.new # header 情報. カテゴリの出力が既に存在するかどうかの判定にも使う.
    @category = String.new # 現在のカテゴリ名
    @prev_value = Hash.new # diff 計算用に前回の値を格納する変数

    @begin_time = Time.at(0)
    @end_time = Time.parse("2038/01/19/ 03:14:07 GMT") # Unix システムでの最大時刻
  end

  # 出力の開始時刻を設定
  def begin_time=(time_str)
    @begin_time = Time.parse(time_str)
  end

  # 出力の終了時刻を設定
  def end_time=(time_str)
    @end_time = Time.parse(time_str)
  end

  def puts(str)
    @lines.shift
    @lines.push(str)

    if unpack_template = header_separator(@lines[1])
      @unpack_template = unpack_template
      header_ary = unpack(@lines[0], @unpack_template)
      @category = unpack(@lines[2], @unpack_template)[CNAME_INDEX]

      @config.each do |config|
        next unless config["name"] == @category
        if config["diff"]
          header_ary.concat(config["diff"]["value"].map {|x| "diff_#{x.to_s}"})
        end
      end

      unless @headers[@category]
        if @categories.nil? || @categories.include?(@category)
          @output_manager.puts(@category, header_ary)
        end
        @headers[@category] = header_ary
      end
    end

    if @unpack_template
      output_ary = unpack(@lines[2], @unpack_template)
    else
      return
    end

    if output_ary[CNAME_INDEX] == @category && within_time?(output_ary[PTIME_INDEX])
      if @categories.nil? || @categories.include?(@category)
        @output_manager.puts(@category, add_diff(output_ary))
      end
    end
  end

  def close
    @config.each do |config|
      category = config["name"]
      if config["pivot"] && (@categories.nil? || @categories.include?(category)) && @output_manager.respond_to?("pivot")
        @output_manager.pivot(category, config["pivot"])
      end
    end
    @output_manager.close
  end

  private
  # "-" と " " だけから成る行ならば, header separator と見なし,
  # unpack 用のテンプレート出力. そうでなければ nil を返す.
  def header_separator(str)
    if str =~ /\A[- ]+\z/
      return str.split(/ /).map {|x| "A" + x.length.to_s}.join("x1")
    else
      return nil
    end
  end

  # 文字列 str を unpack_template に従って unpack する.
  # 文字数が足りない場合にも対応.
  # unpack された文字列の余分な空白を除いて返す.
  def unpack(str, unpack_template)
    # unack_template から文字数を計算.
    str_length = unpack_template.split(/[Ax]/).inject(0) {|sum, x| sum + x.to_i}
    # unpack で文字数が足りずに ArgumentError が出ないように,
    # 足りない分を" "で埋める.
    str = str + " " * (str_length - str.length) if str_length > str.length
    return str.unpack(unpack_template).map {|x| x.strip}
  end

  # 前回からの diff を計算して output_ary に追加.
  def add_diff(output_ary)
    @config.each do |config|
      category = config["name"]
      next unless category == @category
      if diff_conf = config["diff"]
        diff_conf["value"].each do |v|
          id = category + ":" + v + ":" + diff_conf["id"].map {|x| output_ary[@headers[category].index(x)]}.join(":")
          current_value = output_ary[@headers[category].index(v)]
          if @prev_value[id]
            diff = current_value.to_i - @prev_value[id].to_i
          end
          output_ary << diff
          @prev_value[id] = current_value
        end
      end
    end
    return output_ary
  end

  # time_str が @begin_time から @end_time の間か判定
  def within_time?(time_str)
    time = Time.parse(time_str)
    return @begin_time <= time && time <= @end_time
  end
end

class CompareExcel
  MAX_SHEET_NAME_LEN = 31 # Excel のシート名の最大文字数
  OUTPUT_SHEET_NAME = "comparison"

  def initialize
    @excel = WIN32OLE.new('Excel.Application')
    WIN32OLE.const_load(@excel, Excel)
    @excel.Visible = true
    @excel.SheetsInNewWorkbook = 1
    @input_books = []
    @output_book = nil
    @output_book_name = ""
  end

  def input_books(books)
    @input_books = books
  end

  def open_input_book(xlsx_filename)
    abs_filename = get_abs_path(xlsx_filename)
    book = @excel.Workbooks.Open(abs_filename)
    return book
  end

  def open_output_book(xlsx_filename)
    @output_book = @excel.Workbooks.Add
    @output_book_name = get_abs_path(xlsx_filename)
    @output_sheet = @output_book.Sheets.Add
    @output_sheet.Name = OUTPUT_SHEET_NAME
  end

  def copy_charts(sheet_names)
    col = 2
    @input_books.each do |ib|
      input_book = open_input_book(ib)

      row = 2
      sheet_names.each do |sn|
        input_book.Activate

        sheet_exist = false
        input_book.Sheets.each { |sheet| sheet_exist = true if sheet.Name == "#{sn} Graph"[0, MAX_SHEET_NAME_LEN] }
        if sheet_exist
          input_book.Sheets("#{sn} Graph"[0, MAX_SHEET_NAME_LEN]).Select
          @excel.ActiveChart.ChartArea.Copy

          @output_book.Activate
          @output_book.Sheets(OUTPUT_SHEET_NAME).Select
          @output_book.ActiveSheet.Cells(row, col).Select
          @output_book.ActiveSheet.Paste
        end

        row += 25
      end

      input_book.Close(0)
      col += 10
    end

    @output_book.Activate
    @output_book.ActiveSheet.Cells(1, 1).Select

    @output_book.ActiveSheet.ChartObjects.each do |co|
      co.Height = 288
      co.Width = 512
    end
  end

  def close
    @output_book.SaveAs(@output_book_name)
    @output_book.Close(0)

    @excel.Quit
  end

  private
  def get_abs_path(filename)
    fso = WIN32OLE.new('Scripting.FileSystemObject')
    return fso.GetAbsolutePathName(filename)
  end
end

class Option
  # 開始時刻
  attr_accessor :begin_time

  # 終了時刻
  attr_accessor :end_time

  # 出力ファイルの接頭字
  attr_accessor :output

  # 出力するカテゴリの配列
  attr_accessor :categories

  # config ファイルの指定
  attr_accessor :config_file

  # 出力フォーマット
  attr_accessor :format

  attr_accessor :comparison

  def initialize
    @format = "xls"
  end
end

opt = Option.new
begin
  op = OptionParser.new
  op.banner = "Usage: #{File.basename($0)} [options] <file>...\n\n" +
              "Example: ruby #{File.basename($0)} -o output ./coin_log_2009-03-20T*/dbstat/dbstat*\n" +
              "         ruby #{File.basename($0)} -o output -b \"2009-03-20 15:30\" -e \"2009-03-20 16:30\" -c SGASTAT,SYSSTAT ./dbstat*\n" +
              "         ruby #{File.basename($0)} --compare -o comp.xlsx ./output1.xlsx ./output2.xlsx\n" +
              "\n" +
              "Option: "

  op.on('-o', '--output=FILE_PREFIX', String, 'specify output file name prefix') do |arg|
    opt.output = arg
  end
  op.on('-b', '--begin=TIME', String, 'specify begin time (YYYY-MM-DD HH24:MI:SS)') do |arg|
    opt.begin_time = arg
  end
  op.on('-e', '--end=TIME', String, 'specify end time (YYYY-MM-DD HH24:MI:SS)') do |arg|
    opt.end_time = arg
  end
  op.on('-c', '--category=CATEGORY_LIST', Array, 'specify categories to be output (CSV)') do |arg|
    opt.categories = arg
  end
  op.on('-f', '--file=FILE_NAME', String, 'specify config file') do |arg|
    opt.config_file = arg
  end
  op.on('-T', '--format=FORMAT_NAME', String, 'specify output file format (xls, csv)') do |arg|
    opt.format = arg
  end
  op.on('-C', '--compare', 'compare output .xlsx files') do |bool|
    opt.comparison = bool
  end
  op.on('-h', '--help', 'output help') do
    puts op.help
    exit
  end

  op.parse!
  raise "Missing input file." if ARGV.size == 0
  raise "Missing output file prefix." if opt.output.nil?
  raise "Extension of output file name must be \"xlsx\"." if opt.comparison && opt.output !~ /\.xlsx/
rescue
  puts $! if $!.to_s != ""
  #RDoc::usage('Usage', 'Example')
  puts op.help
  exit
end


# main
if opt.comparison
  comp = CompareExcel.new
  comp.open_output_book(opt.output)
  comp.input_books(ARGV)
  if opt.categories
    comp.copy_charts(opt.categories)
  else
    comp.copy_charts(["MPSTAT", "MEMINFO", "IOSTAT", "NETSTAT", "SYSSTAT", "SYSTEM_EVENT", "MEMORY_DYNAMIC_COMPONENTS", "SGASTAT", "KSMSS"])
  end
  comp.close
  exit
end

config_io = opt.config_file ? File.open(opt.config_file) : DATA
config = YAML.load(config_io.read)

remint = Remint.new(config)

case opt.format
when "csv"
  output_mgr = CSVOutputManager.new(opt.output)
else
  output_mgr = ExcelOutputManager.new(opt.output)
end
remint.output_manager = output_mgr

remint.begin_time = opt.begin_time if opt.begin_time
remint.end_time = opt.end_time if opt.end_time
remint.categories = opt.categories

ARGV.each do |argv|
  f = begin
        Zlib::GzipReader.open(argv)
      rescue
        File.open(argv)
      end
  f.each {|line| remint.puts(line.chomp)}
  f.close
end

remint.close

__END__

--- # config ファイル
- name: SGASTAT                  # カテゴリ名(CNAME 列の値)
  diff:                          # 前回採取時刻からの差分を出力する場合に指定(オプション)
    id:                            # 一意性を識別するためのcolumnを指定
      - POOL
      - NAME
    value:                         # 差分を取る column名を指定(複数列挙可能)
      - BYTES
  pivot:                         # ピボットテーブルを作成する場合に指定(オプション)
    RowField: CTIMESTAMP           # 行フィールド
    ColumnField:                   # 列フィールド
      - NAME
    DataField:                     # データフィールド 差分を出力したい場合は上記 diff を設定して "diff_<value名>" を指定.
      - BYTES
    PageField: POOL                # ページフィールド
    CurrentPage: shared pool       # デフォルトのページの値(ページフィールドで取り得る値から指定)
    ChartType: Excel::XlAreaStacked
    PivotFilters:
      Type: Excel::XlTopCount
      Value1: 15

- name: KSMSS
  diff:
    id:
      - 'SUBPOOL#'
      - NAME
    value:
      - BYTES
  pivot:
    RowField: CTIMESTAMP
    ColumnField:
      - NAME
      - 'SUBPOOL#'
    DataField: BYTES
    PageField: CNAME
    CurrentPage: KSMSS
    ChartType: Excel::XlAreaStacked
    PivotFilters:
      Type: Excel::XlTopCount
      Value1: 15

- name: SYSSTAT
  diff:
    id:
      - STATISTIC#
    value:
      - VALUE
  pivot:
    RowField: CTIMESTAMP
    ColumnField: NAME
    DataField:
      - diff_VALUE
    PageField: CLASS
    CurrentPage: 1
    visible:
      - field: NAME
        item:
          - user commits
          - user rollbacks

- name: SYSTEM_EVENT
  diff:
    id:
      - EVENT
    value:
      - TOTAL_WAITS                # 差分を取る列はこのように複数指定可能
      - TIME_WAITED_MICRO
  pivot:
    RowField: CTIMESTAMP
    ColumnField: EVENT
    DataField: diff_TIME_WAITED_MICRO
    PageField: WAIT_CLASS
    CurrentPage: (All)
    ChartType: Excel::XlAreaStacked
    invisible:
      - field: WAIT_CLASS
        item:
          - Idle
    # PivotFilters:
    #   Type: Excel::XlTopCount
    #   Value1: 15

- name: OSSTAT
  diff:
    id:
      - STAT_NAME
    value:
      - VALUE
  pivot:
    RowField: CTIMESTAMP
    ColumnField: STAT_NAME
    DataField: diff_VALUE
    PageField: CUMULATIVE
    CurrentPage: "YES"
    ChartType: Excel::XlAreaStacked100
    invisible:
      - field: STAT_NAME
        item:
          - VM_IN_BYTES
          - VM_OUT_BYTES

- name: SYS_TIME_MODEL
  diff:
    id:
      - STAT_NAME
    value:
      - VALUE
  pivot:
    RowField: CTIMESTAMP
    ColumnField: STAT_NAME
    DataField: diff_VALUE
    PageField: CNAME                # 特に指定したいページフィールドがなければ
    CurrentPage: SYS_TIME_MODEL     # このように CNAME, <category名> を指定する
    ChartType: Excel::XlAreaStacked
    invisible:
      - field: STAT_NAME
        item:
          - DB time
          - background cpu time
          - background elapsed time

- name: MEMORY_DYNAMIC_COMPONENTS
  pivot:
    RowField: CTIMESTAMP
    ColumnField: COMPONENT
    DataField: CURRENT_SIZE
    PageField: CNAME
    CurrentPage: MEMORY_DYNAMIC_COMPONENTS
    ChartType: Excel::XlAreaStacked
    invisible:
      - field: COMPONENT
        item:
          - SGA Target

- name: ENQUEUE_STAT
  diff:
    id:
      # - EQ_TYP           # <= 11.2.0.2
      - EQ
    value:
      - CUM_WAIT_TIME
  pivot:
    RowField: CTIMESTAMP
    # ColumnField: EQ_TYP  # <= 11.2.0.2
    ColumnField: EQ
    DataField: diff_CUM_WAIT_TIME
    PageField: CNAME
    CurrentPage: ENQUEUE_STAT
    ChartType: Excel::XlAreaStacked

- name: MPSTAT
  pivot:
    RowField: CTIMESTAMP
    ColumnField: CPU
    # DataField:    # RHEL 5
    #   - '%user'
    #   - '%nice'
    #   - '%sys'
    #   - '%iowait'
    #   - '%irq'
    #   - '%soft'
    #   - '%steal'
    #   - '%idle'
    DataField:      # RHEL 6 (sysstat version 9)
      - '%usr'
      - '%nice'
      - '%sys'
      - '%iowait'
      - '%irq'
      - '%soft'
      - '%steal'
      - '%guest'
      - '%idle'
    # DataField:    # RHEL 7 (sysstat version 10)
    #   - '%usr'
    #   - '%nice'
    #   - '%sys'
    #   - '%iowait'
    #   - '%irq'
    #   - '%soft'
    #   - '%steal'
    #   - '%guest'
    #   - '%gnice'
    #   - '%idle'
    PageField: CNAME
    CurrentPage: MPSTAT
    ChartType: Excel::XlAreaStacked
    visible:
      - field: CPU
        item:
          - all

- name: MEMINFO
  pivot:
    RowField: CTIMESTAMP
    ColumnField: name
    DataField: value
    PageField: CNAME
    CurrentPage: MEMINFO
    ChartType: Excel::XlAreaStacked
    visible:
      - field: name
        item:
          - MemFree
          - Active
          - Inactive
          - Slab
          - VmallocUsed
          - PageTables

- name: IOSTAT
  pivot:
    RowField: CTIMESTAMP
    ColumnField: 'Device:'
    DataField:
      - r/s
      - w/s
    PageField: CNAME
    CurrentPage: IOSTAT
    ChartType: Excel::XlAreaStacked
    visible:
      - field: 'Device:'
        item:      # 環境に合わせて確認したいデバイス名("sda" 等の iostat 出力の Device 名)に変更すること
          - xvda
          - xvdb
          - xvdc
          - xvdd
          - xvde
          - xvdf
          - xvdg
          - xvdh
          - xvdi
          - xvdj
          - xvdk
          - xvdl

- name: NETSTAT
  diff:
    id:
      - Iface
    value:
      - RX bytes
      - RX packets
      - RX errors
      - RX dropped
      - RX overruns
      - TX bytes
      - TX packets
      - TX errors
      - TX dropped
      - TX overruns
  pivot:
    RowField: CTIMESTAMP
    ColumnField:
      - Iface
    DataField:
      - diff_RX bytes
      - diff_TX bytes
    PageField: CNAME
    CurrentPage: NETSTAT
    ChartType: Excel::XlAreaStacked

- name: IPROUTE
  diff:
    id:
      - Iface
    value:
      - RX bytes
      - RX packets
      - RX errors
      - RX dropped
      - RX overrun
      - RX mcast
      - TX bytes
      - TX packets
      - TX errors
      - TX dropped
      - TX carrier
      - TX collsns
  pivot:
    RowField: CTIMESTAMP
    ColumnField:
      - Iface
    DataField:
      - diff_RX bytes
      - diff_TX bytes
    PageField: CNAME
    CurrentPage: IPROUTE
    ChartType: Excel::XlAreaStacked
