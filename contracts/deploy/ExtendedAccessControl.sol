// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AccessControl.sol";
import "./Counters.sol";

/**
 * @title ExtendedAccessControl
 * @dev This is a extension from openzeppelin AccessControl that allow to require determinated number of admin votes to assign or revoke roles
 */
abstract contract ExtendedAccessControl is AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _emergencyRecoverIds;

    /**
		@dev set required number of votes to assign or revoke role
	**/
    constructor(uint8 requiredVotes) {
        _requiredVotes = requiredVotes;
    }

    uint8 private _requiredVotes;
    /**
		@dev stores  approvals for specific address and role
	**/
    mapping(address => mapping(bytes32 => mapping(address => bool)))
        private _roleApprovalVotation;

    /**
		@dev stores address of administrators that voted to assign a role to a specific address
	**/
    mapping(address => mapping(bytes32 => address[]))
        private _rolesApprovalVotes;

    /**
		@dev stores votes to revoke specific role for an addres
	**/
    mapping(address => mapping(bytes32 => mapping(address => bool)))
        private _roleRevokeVotation;

    /**
		@dev stores address of admnistrators that voted to revoke a role to a specific address
	**/
    mapping(address => mapping(bytes32 => address[])) private _rolesRevokeVotes;

    /**

	*/

    event emergencyRecover(
        uint256 _id,
        uint256 _timestamp,
        bool _isDenied,
        bool _isCompleted,
        uint8 _votes
    );

    struct EmergencyRecoverRequest {
        address _beneficiary;
        uint256 _timestamp;
        bool _isDenied;
        bool _isCompleted;
        uint8 _votes;
    }

    uint256 private constant REQUIRED_EMERGENCY_TIME = 60 days;

    mapping(uint256 => EmergencyRecoverRequest) private _recoverRequest;
    mapping(uint256 => mapping(address => bool)) private _addressVotation;

    function createEmergencyRecover(address _beneficiary)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_beneficiary != address(0));
        require(_beneficiary != _msgSender());

        _emergencyRecoverIds.increment();

        uint256 id = _emergencyRecoverIds.current();

        _recoverRequest[id] = EmergencyRecoverRequest(
            _beneficiary,
            block.timestamp,
            false,
            false,
            1
        );
        _addressVotation[id][_msgSender()] = true;

        emit emergencyRecover(
            id,
            _recoverRequest[id]._timestamp,
            false,
            false,
            1
        );
    }

    function changeEmergencyRecoverStatus(uint256 id, bool isRevokeRequest )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _recoverRequest[id]._beneficiary != address(0),
            "doesn't exist"
        );
        require(_addressVotation[id][_msgSender()] == false, "already voted");
        require(_recoverRequest[id]._isDenied == false, "is denied");
        require(_recoverRequest[id]._isCompleted == false, "already completed");

        if (isRevokeRequest) {
            _recoverRequest[id]._isDenied = true;
        } else {
            _addressVotation[id][_msgSender()] = true;
            _recoverRequest[id]._votes++;
        }

        emit emergencyRecover(
            id,
            _recoverRequest[id]._timestamp,
            _recoverRequest[id]._isDenied,
            _recoverRequest[id]._isCompleted,
            _recoverRequest[id]._votes
        );
    }

    function applyEmergencyRecover(uint256 id)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _recoverRequest[id]._beneficiary != address(0),
            "doesn't exist"
        );
        require(_recoverRequest[id]._isDenied == false, "is denied");
        require(_recoverRequest[id]._isCompleted == false, "already completed");
        require(_recoverRequest[id]._votes > 0, "invalid request");
        uint256 elapsedTime = block.timestamp - _recoverRequest[id]._timestamp;
        uint256 decreaseTime = (15 days * _recoverRequest[id]._votes);
        uint256 requiredElapsedTime = 0;

        if (decreaseTime < REQUIRED_EMERGENCY_TIME) {
            requiredElapsedTime = REQUIRED_EMERGENCY_TIME - decreaseTime;
        }

        require(elapsedTime >= requiredElapsedTime, "can't apply yet");

        _recoverRequest[id]._isCompleted = true;

        super.grantRole(DEFAULT_ADMIN_ROLE, _recoverRequest[id]._beneficiary);

        emit emergencyRecover(
            id,
            _recoverRequest[id]._timestamp,
            _recoverRequest[id]._isDenied,
            _recoverRequest[id]._isCompleted,
            _recoverRequest[id]._votes
        );
    }

    /**
		@dev update votation to revoke role and if the number of votes are greater than the required votes revoke role 
	**/
    function revokeRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {
        _revokeRoleVote(account, role);

        if (_rolesRevokeVotes[account][role].length >= _requiredVotes) {
            super.revokeRole(role, account);
            _restoreVotation(account, role);
        }
    }

    /**
		@dev update votation to assign a role to an address and if the votes are greater than required votes assign role
	**/
    function grantRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {
        _approveRoleVote(account, role);

        if (_rolesApprovalVotes[account][role].length >= _requiredVotes) {
            super.grantRole(role, account);
            _restoreVotation(account, role);
        }
    }

    /**
		@dev update votation to assign a role
	**/
    function _approveRoleVote(address _address, bytes32 _role)
        private
        returns (bool)
    {
        require(_address != address(0));
        require(
            !_roleApprovalVotation[_address][_role][_msgSender()],
            "You can vote only one time"
        );

        _roleApprovalVotation[_address][_role][_msgSender()] = true;
        _rolesApprovalVotes[_address][_role].push(_msgSender());

        return true;
    }

    /**
		@dev update votation to revoke a role
	**/
    function _revokeRoleVote(address _address, bytes32 _role)
        private
        returns (bool)
    {
        require(_address != address(0));
        require(
            !_roleRevokeVotation[_address][_role][_msgSender()],
            "You can vote only one time"
        );

        _roleRevokeVotation[_address][_role][_msgSender()] = true;
        _rolesRevokeVotes[_address][_role].push(_msgSender());

        return true;
    }

    /**
		@dev reset votation for specific address and role
	**/
    function _restoreVotation(address _address, bytes32 _role) private {
        for (
            uint256 i = 0;
            i < _rolesRevokeVotes[_address][_role].length;
            i++
        ) {
            delete _roleRevokeVotation[_address][_role][
                _rolesRevokeVotes[_address][_role][i]
            ];
        }
        delete _rolesRevokeVotes[_address][_role];

        for (
            uint256 i = 0;
            i < _rolesApprovalVotes[_address][_role].length;
            i++
        ) {
            delete _roleApprovalVotation[_address][_role][
                _rolesApprovalVotes[_address][_role][i]
            ];
        }
        delete _rolesApprovalVotes[_address][_role];
    }
}
