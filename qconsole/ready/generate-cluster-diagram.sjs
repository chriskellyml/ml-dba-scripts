/* This script will check your cluster and build a html table visualizing the
 * current topology. Be sure to switch to html view below to see the output as
 * intented */

// TODO: Insert actual script
40 + 2

$("#query-type option").filter(function() {
    return $(this).text() == "SQL"
}).prop('selected', true).parent().trigger('change');

[]

$('#query-type option').each(function() {
    if ($(this).text() == "SQL") { // Replace "Visible Text" with the text you're looking for
        $(this).prop('selected', true);
        return false; // Break the loop once the correct option is found
    }
});
