pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

    mapping(address => mapping(address => uint256)) private _allowance;

    address[] private _holders;
    mapping(address => uint256) private _idx;

    mapping(address => uint256) private _withdrawable;

    uint256 private constant ACCURACY = 1e18;
    uint256 private _dividendPerToken;
    mapping(address => uint256) private _dividendCreditedTo;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function _addHolder(address a) private {
        if (_idx[a] == 0) {
            _holders.push(a);
            _idx[a] = _holders.length;
        }
    }

    function _removeHolder(address a) private {
        uint256 i = _idx[a];
        if (i == 0) {
            return;
        }

        uint256 lastIndex = _holders.length;
        if (i != lastIndex) {
            address lastHolder = _holders[lastIndex - 1];
            _holders[i - 1] = lastHolder;
            _idx[lastHolder] = i;
        }

        _holders.pop();
        _idx[a] = 0;
    }

    function _syncHolder(address a) private {
        if (balanceOf[a] > 0) {
            _addHolder(a);
        } else {
            _removeHolder(a);
        }
    }

    function _updateDividend(address account) private {
        uint256 credited = _dividendCreditedTo[account];
        uint256 current = _dividendPerToken;

        if (credited == current) {
            return;
        }

        uint256 bal = balanceOf[account];
        if (bal > 0) {
            uint256 owed = bal.mul(current.sub(credited)).div(ACCURACY);
            _withdrawable[account] = _withdrawable[account].add(owed);
        }

        _dividendCreditedTo[account] = current;
    }

  // IERC20

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return _allowance[owner][spender];
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        require(to != address(0), "bad to");
        require(balanceOf[msg.sender] >= value, "insufficient balance");

        _updateDividend(msg.sender);
        _updateDividend(to);

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        _syncHolder(msg.sender);
        _syncHolder(to);

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(
        address spender,
        uint256 value
    ) external override returns (bool) {
        _allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        require(to != address(0), "bad to");
        require(balanceOf[from] >= value, "insufficient balance");
        require(
            _allowance[from][msg.sender] >= value,
            "insufficient allowance"
        );

        _updateDividend(from);
        _updateDividend(to);

        _allowance[from][msg.sender] = _allowance[from][msg.sender].sub(value);
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        _syncHolder(from);
        _syncHolder(to);

        emit Approval(from, msg.sender, _allowance[from][msg.sender]);
        emit Transfer(from, to, value);
        return true;
    }

    // IMintableToken

    function mint() external payable override {
        require(msg.value > 0, "no ETH supplied");

        _updateDividend(msg.sender);

        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        totalSupply = totalSupply.add(msg.value);

        _syncHolder(msg.sender);

        emit Transfer(address(0), msg.sender, msg.value);
    }

    function burn(address payable dest) external override {
        require(dest != address(0), "bad dest");

        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "nothing to burn");

        _updateDividend(msg.sender);

        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(amount);

        _syncHolder(msg.sender);

        emit Transfer(msg.sender, address(0), amount);

        (bool ok, ) = dest.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    // IDividends

    function getNumTokenHolders() external view override returns (uint256) {
        return _holders.length;
    }

    function getTokenHolder(
        uint256 index
    ) external view override returns (address) {
        if (index == 0 || index > _holders.length) {
            return address(0);
        }
        return _holders[index - 1];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "no ETH supplied");
        require(totalSupply > 0, "no token supply");

        _dividendPerToken = _dividendPerToken.add(
            msg.value.mul(ACCURACY).div(totalSupply)
        );
    }

    function getWithdrawableDividend(
        address payee
    ) external view override returns (uint256) {
        uint256 pending = 0;
        uint256 bal = balanceOf[payee];
        uint256 credited = _dividendCreditedTo[payee];

        if (bal > 0 && _dividendPerToken > credited) {
            pending = bal.mul(_dividendPerToken.sub(credited)).div(ACCURACY);
        }

        return _withdrawable[payee].add(pending);
    }

    function withdrawDividend(address payable dest) external override {
        require(dest != address(0), "bad dest");

        _updateDividend(msg.sender);

        uint256 amount = _withdrawable[msg.sender];
        require(amount > 0, "no dividend");

        _withdrawable[msg.sender] = 0;

        (bool ok, ) = dest.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }
}
