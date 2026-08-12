const body = $response.body;

if (!body) {
  $done({});
} else {
  try {
    const data = JSON.parse(body);

    data.advertisement_num = 0;
    data.advertisement_info = [];
    delete data.appid;

    $done({ body: JSON.stringify(data) });
  } catch (error) {
    console.log(`WeChat Official Account ad cleanup failed: ${error}`);
    $done({ body });
  }
}