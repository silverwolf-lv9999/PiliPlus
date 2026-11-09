import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show MainListReply, ReplyInfo;
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/dynamic/dyn_mention/item.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/pages/common/reply/fold/reply_fold_mixin.dart';
import 'package:PiliPlus/pages/common/reply/reply_controller.dart';
import 'package:PiliPlus/pages/common/reply/vote/reply_vote_mixin.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/reply_reply/view.dart';
import 'package:PiliPlus/services/breeze/breeze_content.dart';
import 'package:PiliPlus/services/breeze/breeze_rules.dart';
import 'package:PiliPlus/services/breeze/breeze_service.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/reply_scheme_helper.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart' show BoxConstraints, WidgetsBinding;
import 'package:get/get.dart';

class VideoReplyController extends ReplyController<MainListReply>
    with
        ReplyVoteMixin,
        GetSingleTickerProviderStateMixin,
        ReplyLocateMixin,
        MainReplyLocateMixin,
        BaseReplyFoldMixin<MainListReply>,
        ReplyFoldMixin {
  VideoReplyController({
    required this.heroTag,
  });
  late final isPugv = videoCtr.videoType == .pugv;

  @override
  int get oid => isPugv ? videoCtr.epId! : videoCtr.aid;

  @override
  int get replyType => videoCtr.videoType.replyType;

  final String heroTag;
  late final videoCtr = Get.find<VideoDetailController>(tag: heroTag);

  MentionItem? get mentionItem {
    if (videoCtr.isUgc) {
      try {
        return videoCtr.ugcIntroCtr.videoDetail.value.owner?.mentionItem;
      } catch (_) {
        if (kDebugMode) rethrow;
      }
    }
    return null;
  }

  @override
  dynamic get sourceId => IdUtils.av2bv(videoCtr.aid);

  /// The video details the pinned comment is judged with; null until the
  /// intro controller exists.
  Rx<VideoDetailData>? get breezeVideoDetail {
    try {
      return videoCtr.isUgc
          ? Get.find<UgcIntroController>(tag: heroTag).videoDetail
          : Get.find<PgcIntroController>(tag: heroTag).videoDetail;
    } catch (_) {
      return null;
    }
  }

  /// Null until the video details are loaded: the title and uploader are
  /// part of the request, so judging earlier would use missing context.
  BreezeRaw? breezePinnedRaw(ReplyInfo reply) {
    final isUgc = videoCtr.isUgc;
    final detail = breezeVideoDetail?.value;
    final title = detail?.title ?? '';
    // The ugc title is known from the route arguments before the details
    // load; the uploader's name arrives with them.
    final upName = isUgc ? detail?.owner?.name ?? '' : '';
    if (title.isEmpty || (isUgc && upName.isEmpty)) return null;
    final mid = upMid?.toInt() ?? 0;
    return BreezeContent.fromPinnedReply(
      reply,
      upName: upName,
      upMid: mid > 0 ? '$mid' : '',
      title: title,
      url: isUgc
          ? 'https://www.bilibili.com/video/${IdUtils.av2bv(videoCtr.aid)}'
          : 'https://www.bilibili.com/bangumi/play/ep${videoCtr.epId}',
    );
  }

  @override
  bool customHandleResponse(bool isRefresh, Success<MainListReply> response) {
    final handled = super.customHandleResponse(isRefresh, response);
    if (isRefresh && hasUpTop) {
      final reply = response.response.upTop;
      BreezeService.prefetch(() => [breezePinnedRaw(reply)], BreezeKind.pinned);
    }
    return handled;
  }

  @override
  void onAnimRootReply(ReplyInfo rootReply) {
    if (args[secondRpIdKey] case final int secondRpId) {
      clearTargetRootRpId();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => replyReply(rootReply, secondRpId),
      );
    } else {
      super.onAnimRootReply(rootReply);
    }
  }

  void replyReply(ReplyInfo replyItem, int? id) {
    videoCtr.childKey.currentState?.showBottomSheet(
      constraints: const BoxConstraints(),
      (context) => VideoReplyReplyPanel(
        id: id,
        oid: replyItem.oid.toInt(),
        rpid: replyItem.id.toInt(),
        firstFloor: replyItem.replyControl.isNote ? null : replyItem,
        replyType: videoCtr.videoType.replyType,
        isVideoDetail: true,
        isNested: videoCtr.scrollKey.currentContext != null,
        upMid: upMid,
      ),
    );
  }

  @override
  Future<LoadingState<MainListReply>> customGetData() => ReplyGrpc.mainList(
    oid: oid,
    rpid: rootRpId,
    type: replyType,
    mode: mode,
    offset: nextOffset,
  );
}
