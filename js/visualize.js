$(function() {
    $.get("data.json", function(file) {
        $("#graph").highcharts({
            chart: {
                zoomtype: 'x'
            },
            legend: {
                enabled: false
            },
            credits: {
                enabled: false
            },
            title: {
                text: ''
            },
            series: [{
                data: file.data
            }]
        });
    });
});