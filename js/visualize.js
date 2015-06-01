$(function() {
    $.get("data.json", function(file) {
        $.plot("#graph", file.data)
    });
});