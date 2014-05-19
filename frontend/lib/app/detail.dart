part of G0;

/**
 * Shows single image and handles sizing
 */
class Detail{

  int _scrollDelay = 300;
  Stopwatch _stopwatch = new Stopwatch()..start();

  // DOM Elements
  Element _body;
  Element _element;
  Element _cover;
  Element _spinner;
  Element _imageContainer;
  Element _footer;
  Element _user;
  Element _channel;
  Element _date;
  Element _source;
  Element _close;
  Element _prev;
  Element _next;

  // Image meta
  String id;
  String imageUrl;
  String source;
  String user;
  String channel;
  int date;

  int _windowWidth;
  int _windowHeight;

  ImageElement _loadedImage;
  VideoElement _loadedVideo;
  Element _lastLoaded;

  bool _isShown = false;
  bool get isShown => _isShown;

  DateFormat _dateFormat = new DateFormat(G0.DATE_FORMAT);

  StreamController _onLeft = new StreamController.broadcast();
  StreamController _onRight = new StreamController.broadcast();

  Stream get onLeft => _onLeft.stream;
  Stream get onRight => _onRight.stream;

  Detail(){
    _getElements();
    _onResize();
    _eventBindings();
  }

  /**
   * Search document for neccessary DOM elements
   */
  void _getElements(){
    _body = querySelector('body');
    _element = querySelector('#container .detail');
    _cover = querySelector('#container .cover');
    _spinner = _element.querySelector('.spinner');
    _footer = _element.querySelector('.footer');
    _user = _footer.querySelector('.user');
    _channel = _footer.querySelector('.channel');
    _date = _footer.querySelector('.date');
    _source = _footer.querySelector('.source');
    _imageContainer = _element.querySelector('.image-container');
    _close = _element.querySelector('.close');
    _next = _element.querySelector('.next');
    _prev = _element.querySelector('.prev');
  }

  void _eventBindings(){
    _cover.onClick.listen((_) => _hideDetail());
    _close.onClick.listen((_) => _hideDetail());
    _next.onClick.listen((_) => _onRight.add(true));
    _prev.onClick.listen((_) => _onLeft.add(true));

    window.onResize.listen((_) => _onResize());
    window.onKeyUp.listen(_handleKeys);
  }

  /**
   * Saves window width on resize and starts image resizing
   */
  void _onResize(){
    _windowWidth = window.innerWidth;
    _windowHeight = window.innerHeight;
    _setDetailSize(_lastLoaded);
  }

  /**
   * Takes a [LIElement] from .image-list retrievs meta from it and displays
   * singe image
   */
  void show(LIElement target){
    _close.classes.remove('show');
    _imageContainer.innerHtml = '';
    _retrieveImageMeta(target);

    assert(id != null);
    assert(imageUrl != null);

    if(imageUrl.substring(imageUrl.length - 4, imageUrl.length) == 'webm'){
      _loadedVideo = new VideoElement();
      var source = new SourceElement();
      source.src = imageUrl;
      _loadedVideo.append(source);
      _loadedVideo.classes.add('detail-image');
      _loadedVideo.loop = true;
      _loadedVideo.onLoadedData.listen((Event evt) =>  _showVideo(evt.target));
      _lastLoaded = _loadedVideo;
    } else {
      _loadedImage = new ImageElement(src: imageUrl);
      _loadedImage.classes.add('detail-image');
      _loadedImage.onLoad.listen((Event evt) => _showImage(evt.target));
      _lastLoaded = _loadedImage;
    }

    DateTime imgDate = new DateTime.fromMillisecondsSinceEpoch(date);

    _user.innerHtml = user;
    _channel.innerHtml = channel;
    _date.innerHtml = '${_dateFormat.format(imgDate)}';
    _source.innerHtml = source;
    _source.setAttribute('href', source);

    _setUrl();
    _showCover();
    _showDetail();
  }

  void _retrieveImageMeta(LIElement target){
    id = target.dataset['id'];
    imageUrl = target.dataset['image'];
    source = target.dataset['source'];
    user = target.dataset['user'];
    channel = target.dataset['channel'];
    date = int.parse(target.dataset['date']) * 1000 ;
  }


  /**
   * Find [LIElement] by offset and delegates to [show]
   * This is used for offset from queryString
   */
  void showByOffset(String offset){
    LIElement target = querySelector('.image-list li[data-id="$offset"]');
    if(target != null){
      show(target);
    }
  }

  void _showDetail(){
    _spinner.classes.add('show');
    if(!_isShown){
      _element.classes.add('show');
      _footer.classes.add('show');
      _body.classes.add('detail-open');
      _isShown = true;
    }
  }

  void _hideDetail(){
    _element.classes.remove('show');
    _spinner.classes.remove('show');
    _footer.classes.remove('show');
    _body.classes.remove('detail-open');

    _imageContainer.innerHtml = '';
    _hideCover();
    _resetUrl();
    _isShown = false;
  }

  void _resetUrl(){
    window.history.pushState(
        null,
        imageUrl,
        window.location.pathname
    );
  }

  void _setUrl(){
    window.history.pushState(
        null,
        imageUrl,
        window.location.pathname + '?offset=$id'
    );
  }

  void _showCover(){
    _cover.classes.add('show');
  }

  void _hideCover(){
    _cover.classes.remove('show');
  }

  void _showImage(ImageElement img){
    img.dataset['width'] = img.width.toString();
    img.dataset['height'] = img.height.toString();

    _setDetailSize(img);
    _imageContainer.append(_loadedImage);
    _spinner.classes.remove('show');
    _close.classes.add('show');
  }

  void _showVideo(VideoElement video){
    video.dataset['width'] = video.videoWidth.toString();
    video.dataset['height'] = video.videoHeight.toString();

    _setDetailSize(video);
    _imageContainer.append(_loadedVideo);
    _spinner.classes.remove('show');
    _close.classes.add('show');
    _loadedVideo.play();
  }

  /**
   * Calculate and apply optimal image size
   */
  void _setDetailSize(var element){
    if(element == null
      || element.dataset['width'] == null
      || element.dataset['height'] == null
    ){
      return;
    }
    int origWidth = int.parse(element.dataset['width']);
    int origHeight = int.parse(element.dataset['height']);

    int width = origWidth > _windowWidth ? _windowWidth : origWidth;
    double ratio = width / origWidth;
    int height = (origHeight * ratio).ceil();

    //TODO: inject this or move it to config
    int headerHeight = 60;
    int footerHeight = 120;

    if( height + headerHeight + footerHeight > _windowHeight  ){
      height = _windowHeight;
      _element.classes.add('scrollable');
    } else {
      _element.classes.remove('scrollable');
    }

    int left = width >= _windowWidth ? 0 : ((_windowWidth - width) / 2).ceil();
    int top = height >= _windowHeight ? 0 : ((_windowHeight - height) / 2).ceil();

    _element..style.width = '${width}px'
            ..style.height = '${height}px'
            ..style.left = '${left}px'
            ..style.top = '${top}px';
  }

  void _handleKeys(KeyboardEvent evt){
    switch(evt.keyCode){
      case 27:
        _hideDetail();
        break;
    }
  }
}
