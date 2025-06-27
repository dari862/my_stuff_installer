$(function () {

    //Cufon.replace('.headline span');

    $('#filternav a').click(function () {
        var $t, rel, $filteropts;
        $t = $(this);
        $('.active_btn').removeClass('active_btn');
        $t.addClass("active_btn");
        rel = $t.attr('rel');
        $filteropts = $('#filteropts');
        $sidefilter = $('#sidefilter');
        if ($('#' + rel + '_filter_buttons').is(":visible")) {
          $filteropts.hide();
        } else if ($('#dynamicspecialized').is(":visible") && rel == "dynamic") {
          $sidefilter.hide();
        } else {
            $sidefilter.hide();
            $('.opts', $filteropts).hide();
            $('.optsnoline', $filteropts).hide();
            $('.btns', $filteropts).hide();
            $('#funcleg_filter').hide();
            $('#mfuncleg_filter').hide();
            $('#funcarm_filter').hide();
            $('#mfuncarm_filter').hide();
            $('#topic_filter').hide();
            $('#mtopic_filter').hide();
            $('#aquatic_filter').hide();
            $('#maquatic_filter').hide();
            $('#dynamic_filter').hide();
            $('#speech_filter').hide();
            $('#mspeech_filter').hide();
            $('#amputee_filter').hide();
            $('#mamputee_filter').hide();
            $('#body').hide();
            $('#muscle').hide();
            $('#protocol').hide();
            $('#search_filter').hide();
            $('#searchrs').css("margin-left", "0px");
            $('#crittype').css("margin-left", "5px");
            $('#searchrs').css("min-width", "640px");
            if (rel == 'dynamic') {
              DynamicClear(true);
              $('#dynamic_filter').show();
              $('#searchrs').css("margin-left", "120px");
              $('#searchrs').css("min-width", "520px");
              $('#crittype').css("margin-left", "125px");
              $sidefilter.show();
            } else if (rel == 'body' && $('#Specialized').val() == "Leg_Flag") {
              $('#funcleg_filter').show();
              $('#body').show();
            } else if (rel == 'body' && $('#Specialized').val() == "Reaching_Flag") {
              $('#funcarm_filter').show();
              $('#body').show();
            } else if (rel == 'body' && $('#Specialized').val() == "Topics_Flag") {
              $('#topic_filter').show();
              $('#body').show();
            } else if (rel == 'body' && $('#Specialized').val() == "Aquatics_Flag") {
              $('#aquatic_filter').show();
              $('#body').show();
            } else if (rel == 'body' && $('#Specialized').val() == "Speech_Flag") {
              $('#speech_filter').show();
              $('#body').show();
            } else if (rel == 'body' && $('#Specialized').val() == "Pediatrics_Flag") {
              $('#pediatrics_filter').show();
              $('#body').show();
            } else if (rel == 'body' && ($('#Specialized').val() == "Upper_Flag" || $('#Specialized').val() == "Lower_Flag")) {
              $('#amputee_filter').show();
              $('#body').show();
            } else if (rel == 'body' && ($('#Specialized').val() != "Leg_Flag" || $('#Specialized').val() != "Reaching_Flag" || $('#Specialized').val() != "Topics_Flag" || $('#Specialized').val() != "Aquatics_Flag")) {
              $('#body_filter').show();
              $('#body').show();
            } else if (rel == 'muscle' && $('#MSpecialized').val() == "Leg_Flag") {
              $('#mfuncleg_filter').show();
              $('#muscle').show();
            } else if (rel == 'muscle' && $('#MSpecialized').val() == "Reaching_Flag") {
              $('#mfuncarm_filter').show();
              $('#muscle').show();
            } else if (rel == 'muscle' && $('#MSpecialized').val() == "Topics_Flag") {
              $('#mtopic_filter').show();
              $('#muscle').show();
            } else if (rel == 'muscle' && $('#MSpecialized').val() == "Aquatics_Flag") {
              $('#maquatic_filter').show();
              $('#muscle').show();
            } else if (rel == 'muscle' && $('#MSpecialized').val() == "Speech_Flag") {
              $('#mspeech_filter').show();
              $('#muscle').show();
            } else if (rel == 'muscle' && $('#MSpecialized').val() == "Pediatrics_Flag") {
              $('#mpediatrics_filter').show();
              $('#muscle').show();
            } else if (rel == 'muscle' && ($('#MSpecialized').val() == "Upper_Flag" || $('#MSpecialized').val() == "Lower_Flag")) {
              $('#mamputee_filter').show();
              $('#muscle').show();
            } else if (rel == 'muscle' && ($('#MSpecialized').val() != "Leg_Flag" || $('#MSpecialized').val() != "Reaching_Flag" || $('#MSpecialized').val() != "Topics_Flag")) {
              $('#muscle_filter').show();
              $('#muscle').show();
            } else if (rel == 'protocol') {
              $('#protocol_filter').show();
              $('#protocol').show();
            } else if (rel == 'search') {
              $('#search_filter').show();
              $('#search').show();
            }
          $('#' + rel + '_filter_buttons').show();
          if (rel != 'dynamic' && rel != 'history') $filteropts.show();
          if (rel == 'search') $('#Find').focus();
        }
        return false;
    });

    $('#closepanel').click(function () {
        $('#filteropts').hide();
    });
    $('#closepanel2').click(function () {
        $('#filteropts').hide();
    });
    $('#closepanel3').click(function () {
        $('#filteropts').hide();
    });
    $('#closepanel4').click(function () {
      $('#filteropts').hide();
    });
    $('#search').click(function () {
        $('#filteropts').hide();
    });
    $('#search2').click(function () {
        $('#filteropts').hide();
    });
    $('#search3').click(function () {
        $('#filteropts').hide();
    });
    $('#search4').click(function () {
      $('#filteropts').hide();
    });

    //$('#Users, .stepper').spinner({ min: 1, max: 100 });
    //$('.stepperdec').spinner({ stepping: 1.00, decimals: 2 });

});

function isNumber(n) { return !isNaN(parseFloat(n)) && isFinite(n); }

function SQuote(n) { n = n.replace(/'/g, ""); n = n.replace("\\", "/"); return n; }

function GetPrintDate() {
    var ldate = new Date().toLocaleDateString();
    if (ldate.length > 16) {
        holder = new Date();
        ldate = (holder.getMonth() + 1) + "/" + holder.getDate() + "/" + holder.getFullYear();
    }
    return ldate;
}

var bChartPainColors = ['#42E500', '#42E500', '#6FE600', '#E9DB02', '#E9BD02', '#EAA002', '#EA8303', '#EB6603', '#EB4903', '#EC2C04', '#ED0409']
var bChartDifficultyColors = ['#42E500', '#42E500', '#42E500', '#42E500', '#42E500', '#42E500', '#E9AF02', '#E98E02', '#EA6D03', '#EB4C03', '#EC2C04']

var bChart = {
  draw: function (instance) {
    var level = instance.data;
    var isPain = instance.type=='P';
    instance.target.innerHTML = "";
    var bars = new DocumentFragment(), bar;
    for (var i = 0; i < 11; i++) {
      bar = document.createElement("div");
      bar.style.height = ((i + 1) * 3.5) + "px";
      bar.style.background = (level >= i ? (isPain ? bChartPainColors[level] : bChartDifficultyColors[level]) : "lightgrey");
      bars.appendChild(bar);
    }
    var txt = document.createElement("span");
    txt.innerHTML = level;
    bars.appendChild(txt);
    instance.target.appendChild(bars);
  }
}

function isDate(value, sepVal, dayIdx, monthIdx, yearIdx) {
  try {
    //Change the below values to determine which format of date you wish to check. It is set to dd/mm/yyyy by default.
    var DayIndex = dayIdx !== undefined ? dayIdx : 1;
    var MonthIndex = monthIdx !== undefined ? monthIdx : 0;
    var YearIndex = yearIdx !== undefined ? yearIdx : 2;

    value = value.replace(/-/g, "/").replace(/\./g, "/");
    var SplitValue = value.split(sepVal || "/");
    var OK = true;
    if (!(SplitValue[DayIndex].length == 1 || SplitValue[DayIndex].length == 2)) {
      OK = false;
    }
    if (OK && !(SplitValue[MonthIndex].length == 1 || SplitValue[MonthIndex].length == 2)) {
      OK = false;
    }
    if (OK && SplitValue[YearIndex].length != 4) {
      OK = false;
    }
    if (OK) {
      var Day = parseInt(SplitValue[DayIndex], 10);
      var Month = parseInt(SplitValue[MonthIndex], 10);
      var Year = parseInt(SplitValue[YearIndex], 10);
      if (OK = ((Year > 1900) && (Year < 2050))) {
        if (OK = (Month <= 12 && Month > 0)) {

          var LeapYear = (((Year % 4) == 0) && ((Year % 100) != 0) || ((Year % 400) == 0));

          if (OK = Day > 0) {
            if (Month == 2) {
              OK = LeapYear ? Day <= 29 : Day <= 28;
            }
            else {
              if ((Month == 4) || (Month == 6) || (Month == 9) || (Month == 11)) {
                OK = Day <= 30;
              }
              else {
                OK = Day <= 31;
              }
            }
          }
        }
      }
    }
    return OK;
  }
  catch (e) {
    return false;
  }
}


