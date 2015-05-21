$ ->
  $('.file-dropzone').each ->
    url = $(this).data('url')
    $(this).dropzone(
      url: url
      paramName: "page_file[file]"
    )
