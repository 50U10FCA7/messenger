// Copyright © 2022-2024 IT ENGINEERING MANAGEMENT INC,
//                       <https://github.com/team113>
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU Affero General Public License v3.0 as published by the
// Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License v3.0 for
// more details.
//
// You should have received a copy of the GNU Affero General Public License v3.0
// along with this program. If not, see
// <https://www.gnu.org/licenses/agpl-3.0.html>.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:messenger/api/backend/schema.dart';
import 'package:messenger/config.dart';
import 'package:messenger/domain/model/chat.dart';
import 'package:messenger/domain/model/precise_date_time/precise_date_time.dart';
import 'package:messenger/domain/model/session.dart';
import 'package:messenger/domain/model/user.dart';
import 'package:messenger/domain/repository/chat.dart';
import 'package:messenger/domain/repository/contact.dart';
import 'package:messenger/domain/repository/settings.dart';
import 'package:messenger/domain/service/auth.dart';
import 'package:messenger/domain/service/call.dart';
import 'package:messenger/domain/service/chat.dart';
import 'package:messenger/domain/service/contact.dart';
import 'package:messenger/domain/service/my_user.dart';
import 'package:messenger/domain/service/user.dart';
import 'package:messenger/provider/drift/background.dart';
import 'package:messenger/provider/drift/blocklist.dart';
import 'package:messenger/provider/drift/call_credentials.dart';
import 'package:messenger/provider/drift/chat.dart';
import 'package:messenger/provider/drift/chat_credentials.dart';
import 'package:messenger/provider/drift/chat_item.dart';
import 'package:messenger/provider/drift/chat_member.dart';
import 'package:messenger/provider/drift/drift.dart';
import 'package:messenger/provider/drift/my_user.dart';
import 'package:messenger/provider/drift/settings.dart';
import 'package:messenger/provider/drift/user.dart';
import 'package:messenger/provider/gql/graphql.dart';
import 'package:messenger/provider/hive/account.dart';
import 'package:messenger/provider/hive/call_rect.dart';
import 'package:messenger/provider/hive/contact.dart';
import 'package:messenger/provider/hive/contact_sorting.dart';
import 'package:messenger/provider/hive/draft.dart';
import 'package:messenger/provider/hive/favorite_contact.dart';
import 'package:messenger/provider/hive/session_data.dart';
import 'package:messenger/provider/hive/monolog.dart';
import 'package:messenger/provider/hive/credentials.dart';
import 'package:messenger/routes.dart';
import 'package:messenger/store/auth.dart';
import 'package:messenger/store/blocklist.dart';
import 'package:messenger/store/call.dart';
import 'package:messenger/store/chat.dart';
import 'package:messenger/store/contact.dart';
import 'package:messenger/store/my_user.dart';
import 'package:messenger/store/settings.dart';
import 'package:messenger/store/user.dart';
import 'package:messenger/themes.dart';
import 'package:messenger/ui/page/home/page/chat/info/view.dart';
import 'package:messenger/util/platform_utils.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../mock/platform_utils.dart';
import 'chat_direct_link_chat_test.mocks.dart';

@GenerateMocks([GraphQlProvider, PlatformRouteInformationProvider])
void main() async {
  PlatformUtils = PlatformUtilsMock();
  TestWidgetsFlutterBinding.ensureInitialized();
  Config.disableInfiniteAnimations = true;

  final CommonDriftProvider common = CommonDriftProvider.memory();
  final ScopedDriftProvider scoped = ScopedDriftProvider.memory();

  Hive.init('./test/.temp_hive/chat_direct_link_widget');

  var graphQlProvider = Get.put(MockGraphQlProvider());
  when(graphQlProvider.disconnect()).thenAnswer((_) => Future.value);

  final myUserProvider = Get.put(MyUserDriftProvider(common));
  var credentialsProvider = Get.put(CredentialsHiveProvider());
  await credentialsProvider.init();
  await credentialsProvider.clear();
  final accountProvider = AccountHiveProvider();
  await accountProvider.init();

  accountProvider.set(const UserId('me'));
  credentialsProvider.put(
    Credentials(
      AccessToken(
        const AccessTokenSecret('token'),
        PreciseDateTime.now().add(const Duration(days: 1)),
      ),
      RefreshToken(
        const RefreshTokenSecret('token'),
        PreciseDateTime.now().add(const Duration(days: 1)),
      ),
      const UserId('me'),
    ),
  );

  when(graphQlProvider.recentChatsTopEvents(3))
      .thenAnswer((_) => const Stream.empty());
  when(graphQlProvider.incomingCallsTopEvents(3))
      .thenAnswer((_) => const Stream.empty());

  when(graphQlProvider.favoriteChatsEvents(any))
      .thenAnswer((_) => const Stream.empty());

  when(graphQlProvider.getUser(any))
      .thenAnswer((_) => Future.value(GetUser$Query.fromJson({'user': null})));
  when(graphQlProvider.getMonolog()).thenAnswer(
    (_) => Future.value(GetMonolog$Query.fromJson({'monolog': null}).monolog),
  );

  AuthService authService = Get.put(
    AuthService(
      AuthRepository(
        graphQlProvider,
        myUserProvider,
        credentialsProvider,
      ),
      credentialsProvider,
      accountProvider,
    ),
  );
  authService.init();

  router = RouterState(authService);
  router.provider = MockPlatformRouteInformationProvider();

  var contactProvider = Get.put(ContactHiveProvider());
  await contactProvider.init();
  await contactProvider.clear();
  final settingsProvider = Get.put(SettingsDriftProvider(common));
  final userProvider = Get.put(UserDriftProvider(common, scoped));
  final chatItemProvider = Get.put(ChatItemDriftProvider(common, scoped));
  final chatMemberProvider = Get.put(ChatMemberDriftProvider(common, scoped));
  final chatProvider = Get.put(ChatDriftProvider(common, scoped));
  final backgroundProvider = Get.put(BackgroundDriftProvider(common));
  final blocklistProvider = Get.put(BlocklistDriftProvider(common, scoped));
  final callCredentialsProvider =
      Get.put(CallCredentialsDriftProvider(common, scoped));
  final chatCredentialsProvider =
      Get.put(ChatCredentialsDriftProvider(common, scoped));
  var draftProvider = Get.put(DraftHiveProvider());
  await draftProvider.init();
  await draftProvider.clear();
  final callRectProvider = CallRectHiveProvider();
  await callRectProvider.init();
  var monologProvider = MonologHiveProvider();
  await monologProvider.init();
  var sessionProvider = SessionDataHiveProvider();
  await sessionProvider.init();
  var favoriteContactHiveProvider = Get.put(FavoriteContactHiveProvider());
  await favoriteContactHiveProvider.init();
  var contactSortingHiveProvider = Get.put(ContactSortingHiveProvider());
  await contactSortingHiveProvider.init();

  Widget createWidgetForTesting({required Widget child}) {
    return MaterialApp(
      theme: Themes.light(),
      home: Builder(
        builder: (context) {
          router.context = context;
          return Scaffold(body: child);
        },
      ),
    );
  }

  testWidgets('ChatInfoView successfully updates ChatDirectLink',
      (WidgetTester tester) async {
    BigInt ver = BigInt.one;
    when(graphQlProvider.disconnect()).thenAnswer((_) => Future.value);
    when(graphQlProvider.keepOnline()).thenAnswer((_) => const Stream.empty());

    final StreamController<QueryResult> chatEvents = StreamController();
    when(graphQlProvider.chatEvents(
      const ChatId('0d72d245-8425-467a-9ebd-082d4f47850b'),
      any,
      any,
    )).thenAnswer((_) => const Stream.empty());

    when(graphQlProvider
            .getChat(const ChatId('0d72d245-8425-467a-9ebd-082d4f47850b')))
        .thenAnswer(
            (_) => Future.value(GetChat$Query.fromJson({'chat': chatData})));

    when(graphQlProvider.recentChats(
      first: anyNamed('first'),
      after: null,
      last: null,
      before: null,
      noFavorite: anyNamed('noFavorite'),
      withOngoingCalls: anyNamed('withOngoingCalls'),
    )).thenAnswer((_) => Future.value(RecentChats$Query.fromJson(recentChats)));

    when(graphQlProvider.favoriteChats(
      first: anyNamed('first'),
      after: null,
      last: null,
      before: null,
    )).thenAnswer(
        (_) => Future.value(FavoriteChats$Query.fromJson(favoriteChats)));

    when(graphQlProvider.incomingCalls()).thenAnswer((_) => Future.value(
        IncomingCalls$Query$IncomingChatCalls.fromJson({'nodes': []})));

    when(graphQlProvider.incomingCallsTopEvents(3))
        .thenAnswer((_) => const Stream.empty());

    when(graphQlProvider.createChatDirectLink(any,
            groupId: const ChatId('0d72d245-8425-467a-9ebd-082d4f47850b')))
        .thenAnswer((_) {
      ver = ver + BigInt.one;
      var event = {
        '__typename': 'ChatEventsVersioned',
        'events': [
          {
            '__typename': 'EventChatDirectLinkUpdated',
            'chatId': '0d72d245-8425-467a-9ebd-082d4f47850b',
            'directLink': {'slug': 'link', 'usageCount': 0}
          }
        ],
        'ver': '$ver'
      };

      chatEvents.add(QueryResult.internal(
        data: {'chatEvents': event},
        parserFn: (_) => null,
        source: null,
      ));

      return Future.value(CreateChatDirectLink$Mutation.fromJson({
        'createChatDirectLink': event,
      }).createChatDirectLink as ChatEventsVersionedMixin?);
    });

    when(graphQlProvider.deleteChatDirectLink(
      groupId: const ChatId('0d72d245-8425-467a-9ebd-082d4f47850b'),
    )).thenAnswer(
      (_) {
        ver = ver + BigInt.one;
        var event = {
          '__typename': 'ChatEventsVersioned',
          'events': [
            {
              '__typename': 'EventChatDirectLinkDeleted',
              'chatId': '0d72d245-8425-467a-9ebd-082d4f47850b',
            }
          ],
          'ver': '$ver'
        };
        chatEvents.add(QueryResult.internal(
          data: {'chatEvents': event},
          parserFn: (_) => null,
          source: null,
        ));

        return Future.value();
      },
    );

    when(graphQlProvider.contactsEvents(any)).thenAnswer(
      (_) => Stream.fromIterable([
        QueryResult.internal(
          parserFn: (_) => null,
          source: null,
          data: {
            'chatContactsEvents': {
              '__typename': 'ChatContactsList',
              'chatContacts': {'nodes': [], 'ver': '0'},
              'favoriteChatContacts': {'nodes': []},
            }
          },
        )
      ]),
    );

    when(graphQlProvider.chatMembers(
      const ChatId('0d72d245-8425-467a-9ebd-082d4f47850b'),
      first: anyNamed('first'),
    )).thenAnswer((_) => Future.value(GetMembers$Query.fromJson({
          'chat': {
            'members': {
              'edges': [],
              'pageInfo': {
                'endCursor': 'endCursor',
                'hasNextPage': false,
                'startCursor': 'startCursor',
                'hasPreviousPage': false,
              }
            }
          }
        })));

    when(graphQlProvider.myUserEvents(any))
        .thenAnswer((_) async => const Stream.empty());

    UserRepository userRepository =
        Get.put(UserRepository(graphQlProvider, userProvider));
    AbstractSettingsRepository settingsRepository = Get.put(
      SettingsRepository(
        const UserId('me'),
        settingsProvider,
        backgroundProvider,
        callRectProvider,
      ),
    );
    final callRepository = CallRepository(
      graphQlProvider,
      userRepository,
      callCredentialsProvider,
      chatCredentialsProvider,
      settingsRepository,
      me: const UserId('me'),
    );
    AbstractChatRepository chatRepository = Get.put<AbstractChatRepository>(
      ChatRepository(
        graphQlProvider,
        chatProvider,
        chatItemProvider,
        chatMemberProvider,
        callRepository,
        draftProvider,
        userRepository,
        sessionProvider,
        monologProvider,
        me: const UserId('me'),
      ),
    );
    AbstractContactRepository contactRepository = ContactRepository(
      graphQlProvider,
      contactProvider,
      favoriteContactHiveProvider,
      contactSortingHiveProvider,
      UserRepository(graphQlProvider, userProvider),
      sessionProvider,
    );

    Get.put(ContactService(contactRepository));
    Get.put(UserService(userRepository));
    ChatService chatService = Get.put(ChatService(chatRepository, authService));
    Get.put(CallService(authService, chatService, callRepository));

    BlocklistRepository blocklistRepository = BlocklistRepository(
      graphQlProvider,
      blocklistProvider,
      userRepository,
      sessionProvider,
      myUserProvider,
      me: const UserId('me'),
    );

    MyUserRepository myUserRepository = Get.put(
      MyUserRepository(
        graphQlProvider,
        myUserProvider,
        blocklistRepository,
        userRepository,
        accountProvider,
      ),
    );
    Get.put(MyUserService(authService, myUserRepository));

    await tester.pumpWidget(createWidgetForTesting(
      child: const ChatInfoView(ChatId('0d72d245-8425-467a-9ebd-082d4f47850b')),
    ));

    // TODO: This waits for lazy [Hive] boxes to finish receiving events, which
    //       should be done in a more strict way.
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(() => Future.delayed(1.milliseconds));
    }
    await tester.pumpAndSettle(const Duration(seconds: 20));

    final editLink = find.byKey(const Key('CreateLinkButton'));
    await tester.dragUntilVisible(
      editLink,
      find.byKey(const Key('ChatInfoScrollable')),
      const Offset(0, 100),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('CreateLinkButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('SaveLinkButton')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    verify(graphQlProvider.createChatDirectLink(
      any,
      groupId: const ChatId('0d72d245-8425-467a-9ebd-082d4f47850b'),
    ));

    await Future.wait([common.close(), scoped.close()]);
    await Get.deleteAll(force: true);
  });

  await contactProvider.clear();
  await chatProvider.clear();
}

final chatData = {
  '__typename': 'Chat',
  'id': '0d72d245-8425-467a-9ebd-082d4f47850b',
  'avatar': null,
  'name': 'null',
  'members': {'nodes': [], 'totalCount': 0},
  'kind': 'GROUP',
  'isHidden': false,
  'muted': null,
  'directLink': null,
  'createdAt': '2021-12-27T14:19:14.828+00:00',
  'updatedAt': '2021-12-27T14:19:14.828+00:00',
  'lastReads': [],
  'lastDelivery': '1970-01-01T00:00:00+00:00',
  'lastItem': null,
  'lastReadItem': null,
  'unreadCount': 0,
  'totalCount': 0,
  'ongoingCall': null,
  'ver': '0'
};

final recentChats = {
  'recentChats': {
    'edges': [
      {
        'node': chatData,
        'cursor': 'cursor',
      }
    ],
    'pageInfo': {
      'endCursor': 'endCursor',
      'hasNextPage': false,
      'startCursor': 'startCursor',
      'hasPreviousPage': false,
    }
  }
};

final favoriteChats = {
  'favoriteChats': {
    'edges': [],
    'pageInfo': {
      'endCursor': 'endCursor',
      'hasNextPage': false,
      'startCursor': 'startCursor',
      'hasPreviousPage': false,
    },
    'ver': '0'
  }
};
