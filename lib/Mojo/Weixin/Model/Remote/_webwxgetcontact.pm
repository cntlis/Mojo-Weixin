use strict;
use Mojo::Weixin::Const qw(%KEY_MAP_USER %KEY_MAP_GROUP %KEY_MAP_GROUP_MEMBER %KEY_MAP_FRIEND);
sub Mojo::Weixin::_webwxgetcontact {
    my $self = shift;
    my $api = "https://".$self->domain . "/cgi-bin/mmwebwx-bin/webwxgetcontact";
    my $flag = 0;
    my $seq = 0;
    my @friends;
    my @groups;
    my $getcontactcallback;
    #return [\@friends,\@groups];
    
    my $callback = sub {
        $self->debug("_webwxgetcontact执行回调".$api);
        my $json = shift;
        my $continueget= 0;
        if (not defined $json){
            $self->warn("getcontact未获取到好友数据");
        }else{
            $self->info("getcontact获取到好友数据");
        }
        if ($json->{BaseResponse}{Ret}!=0){
            $self->warn("getcontact获取数据异常".$json->{BaseResponse}{Ret});
        }else{
            $continueget= 1;
        }
        $self->info("getcontact本次获取MemberCount为".$json->{MemberCount});
        if (($self->is_update_all_friend and defined $json->{Seq} and $json->{Seq} != 0)){
            #获取的不全，需要继续获取其余部分
            my @query_string = (
                r           =>  $self->now(),
                seq         =>  $seq,
                lang        =>  'zh_CN',
                skey        =>  $self->skey,
            );
            
            $flag = 1 ;
            $seq = $json->{Seq};
            $self->info("getcontact获取联系人不全，继续获取联系人");
            
            #my $callback0= $self;
            my $id = $self->http_get($self->gen_url($api,@query_string),{blocking=>0,Referer=>'https://'.$self->domain . '/',json=>1, ua_connect_timeout=>10,ua_request_timeout=>60,ua_inactivity_timeout=>60}, $getcontactcallback);
            #$self->_synccheck_connection_id($id);
        }
        if (defined $json){
            #先清空数组
            @friends= ();
            @groups= ();
            
            #循环拼凑数据开始
            for my $e ( @{ $json->{MemberList} } ){
                if($self->is_group_id($e->{UserName})){
                    my $group = {};
                    for(keys %KEY_MAP_GROUP){
                        $group->{$_} = $e->{$KEY_MAP_GROUP{$_}} // "";
                    }
                    for my $m (@{$e->{MemberList}}){
                        my $member = {};
                        for(keys %KEY_MAP_GROUP_MEMBER){
                            $member->{$_} = $m->{$KEY_MAP_GROUP_MEMBER{$_}} // "";
                        }
                        $member->{sex} = $self->code2sex($member->{sex});
                        push @{$group->{member}},$member;
                    }
                    push @groups,$group;
                }
                else{
                    my $friend = {};
                    for(keys %KEY_MAP_FRIEND){
                        $friend->{$_} = $e->{$KEY_MAP_FRIEND{$_}} // "" ;
                    }
                    $friend->{sex} = $self->code2sex($friend->{sex});
                    push @friends,$friend;
                }
            }
			$self->info("getcontact开始更新数据");
            #异步之后不能批量调用
            $self->add_friend_withnoemit(Mojo::Weixin::Friend->new($_)) for @friends;
            $self->add_group_withnoemit(Mojo::Weixin::Group->new($_)) for @groups;
            #update_friend
			$self->info("getcontact执行update_friend事件更新");
            $self->emit(update_friend=>$self->friend);
			$self->info("getcontact更新数据成功");
        }
    };
    
    #开启异步模式
    my @query_string0 = (
        r           =>  $self->now(),
        seq         =>  $seq,
        lang        =>  'zh_CN',
        skey        =>  $self->skey,
    );
    push @query_string0,(pass_ticket=>$self->url_escape($self->pass_ticket)) if $self->pass_ticket;

    $self->debug("_webwxgetcontact开始获取".$api);
    my $json = $self->http_get($self->gen_url($api,@query_string0),{blocking=>0,Referer=>'https://'.$self->domain . '/',json=>1, ua_retry_times=>1, ua_connect_timeout=>10,ua_request_timeout=>90,ua_inactivity_timeout=>30}, $callback);
    $getcontactcallback= $callback;
    $self->debug("_webwxgetcontact获取API结束");
    return [\@friends,\@groups];
    #避免影响业务，这里直接返回
    
    #微信这个接口屏蔽太严重，暂时直接返回
    do {
        my @query_string = (
            r           =>  $self->now(),
            seq         =>  $seq,
            lang        =>  'zh_CN',
            skey        =>  $self->skey,
        );
        push @query_string,(pass_ticket=>$self->url_escape($self->pass_ticket)) if $self->pass_ticket;

        $self->info("开始获取".$api);
        my $json = $self->http_get($self->gen_url($api,@query_string),{Referer=>'https://'.$self->domain . '/',json=>1, ua_connect_timeout=>10,ua_request_timeout=>60,ua_inactivity_timeout=>30});
        $self->info("获取_webwxgetcontact的API结束");
        #微信会封掉这里的接口，所以这里修改尝试的最大次数，把时间降到最低
        #同时，如果没有获取到数据直接返回空数据
        return [\@friends,\@groups] if not defined $json;
        return if $json->{BaseResponse}{Ret}!=0;
        return if $json->{MemberCount} == 0;
        if ($self->is_update_all_friend and defined $json->{Seq} and $json->{Seq} != 0){#获取的不全，需要继续获取其余部分
            $flag = 1 ;
            $seq = $json->{Seq};
        }
        else{
            $flag = 0;
        }
        for my $e ( @{ $json->{MemberList} } ){
            if($self->is_group_id($e->{UserName})){
                my $group = {};
                for(keys %KEY_MAP_GROUP){
                    $group->{$_} = $e->{$KEY_MAP_GROUP{$_}} // "";
                }
                for my $m (@{$e->{MemberList}}){
                    my $member = {};
                    for(keys %KEY_MAP_GROUP_MEMBER){
                        $member->{$_} = $m->{$KEY_MAP_GROUP_MEMBER{$_}} // "";
                    }
                    $member->{sex} = $self->code2sex($member->{sex});
                    push @{$group->{member}},$member;
                }
                push @groups,$group;
            }
            else{
                my $friend = {};
                for(keys %KEY_MAP_FRIEND){
                    $friend->{$_} = $e->{$KEY_MAP_FRIEND{$_}} // "" ;
                }
                $friend->{sex} = $self->code2sex($friend->{sex});
                push @friends,$friend;
            }
        }
    } while $flag;
    return [\@friends,\@groups];
}
    
1;
