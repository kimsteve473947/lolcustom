import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lol_custom_game_manager/constants/app_theme.dart';
import 'package:lol_custom_game_manager/models/models.dart';
import 'package:lol_custom_game_manager/providers/app_state_provider.dart';
import 'package:lol_custom_game_manager/services/firebase_service.dart';
import 'package:lol_custom_game_manager/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class DirectMessageScreen extends StatefulWidget {
  final String roomId;
  
  const DirectMessageScreen({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  State<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends State<DirectMessageScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  DirectMessageRoom? _room;
  List<DirectMessage> _messages = [];
  DocumentSnapshot? _lastMessageDoc;
  bool _hasMoreMessages = true;
  
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isSendingMessage = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  
  File? _imageFile;
  bool _isUploading = false;
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // 초기 데이터 로드
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 현재 사용자 정보
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      _currentUser = appState.currentUser;
      
      if (_currentUser == null) {
        setState(() {
          _errorMessage = '로그인이 필요합니다';
          _isLoading = false;
        });
        return;
      }
      
      // 채팅방 정보
      final room = await _firebaseService.getDirectMessageRoom(widget.roomId);
      
      if (room == null) {
        setState(() {
          _errorMessage = '채팅방을 찾을 수 없습니다';
          _isLoading = false;
        });
        return;
      }
      
      // 사용자가 해당 채팅방에 속해 있는지 확인
      if (!room.hasUser(_currentUser!.uid)) {
        setState(() {
          _errorMessage = '이 채팅방에 접근할 수 없습니다';
          _isLoading = false;
        });
        return;
      }
      
      // 메시지 로드
      final messages = await _firebaseService.getDirectMessages(roomId: widget.roomId);
      
      setState(() {
        _room = room;
        _messages = messages;
        
        if (messages.isNotEmpty) {
          _lastMessageDoc = messages.last as DocumentSnapshot?;
          _hasMoreMessages = messages.length >= 20;
        } else {
          _hasMoreMessages = false;
        }
      });
      
      // 읽음 상태 업데이트
      await _firebaseService.markDirectMessagesAsRead(
        roomId: widget.roomId,
        userId: _currentUser!.uid,
      );
    } catch (e) {
      setState(() {
        _errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 추가 메시지 로드
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _lastMessageDoc == null) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final messages = await _firebaseService.getDirectMessages(
        roomId: widget.roomId,
        startAfter: _lastMessageDoc,
      );
      
      if (messages.isNotEmpty) {
        setState(() {
          _messages.addAll(messages);
          _lastMessageDoc = messages.last as DocumentSnapshot?;
          _hasMoreMessages = messages.length >= 20;
        });
      } else {
        setState(() {
          _hasMoreMessages = false;
        });
      }
    } catch (e) {
      debugPrint('추가 메시지를 불러오는 중 오류 발생: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
  
  // 메시지 전송
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _imageFile == null) return;
    
    setState(() {
      _isSendingMessage = true;
    });
    
    try {
      String? imageUrl;
      
      // 이미지가 있는 경우 업로드
      if (_imageFile != null) {
        setState(() {
          _isUploading = true;
        });
        
        final bytes = await _imageFile!.readAsBytes();
        final path = 'chat_images/${widget.roomId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        imageUrl = await _firebaseService.uploadImage(path, bytes);
        
        if (imageUrl == null && text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 업로드에 실패했습니다.')),
          );
          setState(() {
            _isUploading = false;
            _isSendingMessage = false;
            _imageFile = null;
          });
          return;
        }

        setState(() {
          _isUploading = false;
          _imageFile = null;
        });
      }
      
      // 메시지 전송
      await _firebaseService.sendDirectMessage(
        roomId: widget.roomId,
        senderId: _currentUser!.uid,
        senderName: _currentUser!.nickname,
        text: text,
        senderProfileUrl: _currentUser!.profileImageUrl,
        imageUrl: imageUrl,
      );
      
      _messageController.clear();
      
      // 최신 메시지 다시 불러오기
      final messages = await _firebaseService.getDirectMessages(roomId: widget.roomId, limit: 20);
      
      setState(() {
        _messages = messages;
        if (messages.isNotEmpty) {
          _lastMessageDoc = messages.last as DocumentSnapshot?;
        }
      });
      
      // 스크롤을 아래로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
    }
  }
  
  // 이미지 선택
  Future<void> _pickImage() async {
    final imagePicker = ImagePicker();
    final pickedImage = await imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    
    if (pickedImage != null) {
      setState(() {
        _imageFile = File(pickedImage.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('로딩 중...')),
        body: const LoadingIndicator(),
      );
    }
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('오류')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_room == null || _currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('채팅')),
        body: const Center(
          child: Text('채팅방 정보를 불러올 수 없습니다'),
        ),
      );
    }
    
    final otherUserName = _room!.getOtherUserName(_currentUser!.uid);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: _room!.getOtherUserProfileUrl(_currentUser!.uid) != null
                  ? NetworkImage(_room!.getOtherUserProfileUrl(_currentUser!.uid)!) as ImageProvider
                  : const AssetImage('assets/images/default_profile.png') as ImageProvider,
            ),
            const SizedBox(width: 8),
            Text(otherUserName),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: Column(
        children: [
          // 메시지 목록
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      '메시지가 없습니다.\n첫 메시지를 보내보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification) {
                        if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && _hasMoreMessages) {
                          _loadMoreMessages();
                        }
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_hasMoreMessages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_hasMoreMessages && index == _messages.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        
                        final message = _messages[index];
                        final isMe = message.senderId == _currentUser!.uid;
                        
                        return _buildMessageItem(message, isMe);
                      },
                    ),
                  ),
          ),
          
          // 이미지 미리보기
          if (_imageFile != null)
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _imageFile!,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _imageFile = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isUploading)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          
          // 메시지 입력 영역
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _isSendingMessage
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: AppColors.primary,
                          ),
                    onPressed: _isSendingMessage ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 메시지 아이템 위젯
  Widget _buildMessageItem(DirectMessage message, bool isMe) {
    final messageTime = DateFormat('HH:mm').format(message.timestamp.toDate());
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderProfileUrl != null
                  ? NetworkImage(message.senderProfileUrl!) as ImageProvider
                  : const AssetImage('assets/images/default_profile.png') as ImageProvider,
            ),
            const SizedBox(width: 8),
          ],
          
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    message.senderName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        messageTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  
                  // 메시지 내용
                  if (message.imageUrl != null)
                    GestureDetector(
                      onTap: () {
                        // 이미지 전체 화면 보기
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Image.network(message.imageUrl!),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          message.imageUrl!,
                          width: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    
                  if (message.text.isNotEmpty)
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primary : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        messageTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}