<! -- 添加捐赠图标 -->
<div class ="post-donate">
    <div id="donate_board" class="donate_bar center">
        <a id="btn_donate" class="btn_donate" href="javascript:;" title="打赏"></a>
        <span class="donate_txt">
           <br>
		   {{ theme.donate_message }}
        </span>
        <br>
      </div>  
	<div id="donate_guide" class="donate_bar center hidden" >
		<a id="donate_weixin" href="{{ url_for(theme.images) }}/weixin.jpg" class="fancybox" rel="article0">
			<img src="{{ url_for(theme.images) }}/weixin.jpg" fuck="微信打赏"/> 
		</a>&nbsp;
		<a id="donate_zhifubao" href="{{ url_for(theme.images) }}/weixin.jpg" class="fancybox" rel="article0">
			<img src="{{ url_for(theme.images) }}/zhifubao.jpg" fuck="支付宝打赏"/>
		</a>  
    </div>
	<script type="text/javascript">
		document.getElementById('btn_donate').onclick = function(){
			$('#donate_board').addClass('hidden');
			$('#donate_guide').removeClass('hidden');
		}
	</script>
</div>
<! -- 添加捐赠图标 -->
